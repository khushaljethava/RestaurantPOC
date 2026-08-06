// Database Webhook target for public.orders INSERT (status=pending).
// Dashboard → Database → Webhooks → Insert on public.orders
//   URL: https://<project>.supabase.co/functions/v1/notify-new-order
// Secret FCM_SERVICE_ACCOUNT = Firebase service-account JSON string.
// Without the secret → 200 no-op (Realtime still delivers to open apps).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v5.9.6/index.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  const sa = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!sa) {
    return Response.json({ ok: true, skipped: "no FCM_SERVICE_ACCOUNT" });
  }

  let body: {
    record?: {
      stall_id?: string;
      token_no?: number;
      id?: string;
      status?: string;
    };
  };
  try {
    body = await req.json();
  } catch {
    return new Response("bad json", { status: 400 });
  }

  const record = body.record;
  if (!record?.stall_id || record.status !== "pending") {
    return Response.json({ ok: true, skipped: "not pending insert" });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: tokens, error } = await supabase
    .from("device_push_token")
    .select("token")
    .eq("stall_id", record.stall_id);

  if (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }
  if (!tokens?.length) {
    return Response.json({ ok: true, sent: 0 });
  }

  const creds = JSON.parse(sa) as {
    client_email: string;
    private_key: string;
    project_id: string;
  };

  const accessToken = await getGoogleAccessToken(creds);
  const url =
    `https://fcm.googleapis.com/v1/projects/${creds.project_id}/messages:send`;

  let sent = 0;
  for (const row of tokens) {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: row.token,
          notification: {
            title: "New order",
            body: `Token #${record.token_no ?? "—"}`,
          },
          data: {
            order_id: String(record.id ?? ""),
            stall_id: record.stall_id,
          },
        },
      }),
    });
    if (res.ok) sent++;
  }

  return Response.json({ ok: true, sent });
});

async function getGoogleAccessToken(creds: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const key = await importPKCS8(creds.private_key, "RS256");
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(creds.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const tokenJson = await tokenRes.json();
  if (!tokenJson.access_token) {
    throw new Error(`token exchange failed: ${JSON.stringify(tokenJson)}`);
  }
  return tokenJson.access_token as string;
}
