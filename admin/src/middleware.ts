import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (list) => {
          list.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          list.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const { data: { user } } = await supabase.auth.getUser();

  const isPublic =
    request.nextUrl.pathname.startsWith('/login') ||
    request.nextUrl.pathname.startsWith('/onboarding') ||
    // Invite landing page. Recipients are by definition not signed in yet —
    // redirecting them to /login here would discard the ?code= and break the
    // entire invite flow.
    request.nextUrl.pathname.startsWith('/join') ||
    request.nextUrl.pathname.startsWith('/r');
  const isDocument = request.headers.get('sec-fetch-dest') === 'document';
  // Only redirect real navigations — never rewrite fetch/XHR (e.g. misconfigured
  // Supabase URL posting to this origin) into POST /login → static 405.
  if (!user && !isPublic && isDocument) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
  return response;
}

export const config = {
  // .well-known is excluded so Google's App Links verification fetch of
  // assetlinks.json doesn't trigger a Supabase auth round-trip.
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.well-known).*)'],
};
