-- Cloud projects (May 2026+) no longer give API roles USAGE on public by default.
-- Without it, RPC calls fail with 403 "permission denied for schema public".

grant usage on schema public to anon, authenticated, service_role;
