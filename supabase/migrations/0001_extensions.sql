-- pgtap powers `supabase test db`; pgcrypto gives us gen_random_bytes for invite codes.
create extension if not exists pgtap with schema extensions;
create extension if not exists pgcrypto with schema extensions;
