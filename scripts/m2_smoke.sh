#!/usr/bin/env bash
# M2 smoke: register stall → menu → create_order → ready → complete
set -euo pipefail

API="${SUPABASE_URL:-http://127.0.0.1:54321}"
ANON="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"
EMAIL="m2smoke_$(date +%s)@test.local"
PASS="password123"

echo "== signup $EMAIL =="
SIGNUP=$(curl -sf "$API/auth/v1/signup" \
  -H "apikey: $ANON" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
TOKEN=$(echo "$SIGNUP" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
AUTH=( -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" )

echo "== register_stall =="
STALL=$(curl -sf "$API/rest/v1/rpc/register_stall" "${AUTH[@]}" \
  -d '{"p_name":"M2 Smoke Stall","p_gst_no":null}')
STALL_ID=$(echo "$STALL" | tr -d '"')
echo "stall=$STALL_ID"

echo "== create menu item =="
ITEM=$(curl -sf "$API/rest/v1/menu_item" "${AUTH[@]}" \
  -H "Prefer: return=representation" \
  -d "{\"stall_id\":\"$STALL_ID\",\"name\":\"Smoke Dosa\",\"price\":80,\"tax_rate\":5}")
ITEM_ID=$(echo "$ITEM" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
echo "item=$ITEM_ID"

echo "== create stall invite + staff redeem =="
INVITE=$(curl -sf "$API/rest/v1/rpc/create_stall_invite" "${AUTH[@]}" \
  -d "{\"p_stall_id\":\"$STALL_ID\",\"p_role\":\"staff\"}" | tr -d '"')
STAFF_EMAIL="m2staff_$(date +%s)@test.local"
STAFF_SIGNUP=$(curl -sf "$API/auth/v1/signup" \
  -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d "{\"email\":\"$STAFF_EMAIL\",\"password\":\"$PASS\"}")
STAFF_TOKEN=$(echo "$STAFF_SIGNUP" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
SAUTH=( -H "apikey: $ANON" -H "Authorization: Bearer $STAFF_TOKEN" -H "Content-Type: application/json" )
curl -sf "$API/rest/v1/rpc/redeem_stall_invite" "${SAUTH[@]}" \
  -d "{\"p_code\":\"$INVITE\"}" >/dev/null
echo "staff joined via $INVITE"

KEY=$(python3 -c "import uuid; print(uuid.uuid4())")
echo "== create_order pending (as staff) =="
ORDER=$(curl -sf "$API/rest/v1/rpc/create_order" "${SAUTH[@]}" \
  -d "{\"p_stall_id\":\"$STALL_ID\",\"p_recorded_by_stall_id\":\"$STALL_ID\",\"p_idempotency_key\":\"$KEY\",\"p_status\":\"pending\",\"p_items\":[{\"menu_item_id\":\"$ITEM_ID\",\"qty\":2}]}")
ORDER_ID=$(echo "$ORDER" | tr -d '"')
echo "order=$ORDER_ID"

echo "== set ready =="
curl -sf "$API/rest/v1/rpc/set_order_status" "${SAUTH[@]}" \
  -d "{\"p_order_id\":\"$ORDER_ID\",\"p_status\":\"ready\"}" >/dev/null

echo "== set completed =="
curl -sf "$API/rest/v1/rpc/set_order_status" "${SAUTH[@]}" \
  -d "{\"p_order_id\":\"$ORDER_ID\",\"p_status\":\"completed\"}" >/dev/null

STATUS=$(curl -sf "$API/rest/v1/orders?id=eq.$ORDER_ID&select=status,token_no" "${SAUTH[@]}" \
  -H "Accept: application/json")
echo "final=$STATUS"

python3 - <<PY
import json
row = json.loads('''$STATUS''')[0]
assert row['status'] == 'completed', row
assert row['token_no'] == 1, row
print('M2 smoke OK (invite → order → complete)')
PY
