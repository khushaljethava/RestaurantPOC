-- FCM dispatch moved to Edge Function notify-new-order + Database Webhook.
-- Dashboard: Database → Webhooks → Insert on public.orders → filter status=pending
-- → POST https://<project>.supabase.co/functions/v1/notify-new-order
-- Secret FCM_SERVICE_ACCOUNT = Firebase service account JSON (optional; no-op without it).

drop trigger if exists orders_notify_new on public.orders;
drop function if exists public.notify_new_order_stub();
