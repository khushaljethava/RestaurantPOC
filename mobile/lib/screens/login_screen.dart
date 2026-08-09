import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../invite_code.dart';
import '../services/google_auth.dart';
import '../theme/ros_theme.dart';
import '../widgets/ros_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  var _emailExpanded = false;
  String? _error;

  String? get _pendingInvite =>
      GoRouterState.of(context).uri.queryParameters['invite'];

  void _goAfterAuth() {
    if (!mounted) return;
    context.go(pathAfterAuth(_pendingInvite));
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    logSupabaseConfig('login-google');
    try {
      await signInWithGoogle();
      _goAfterAuth();
    } catch (e, st) {
      debugPrint('[auth/login-google] error=$e\n$st');
      final msg = mapGoogleAuthError(e);
      if (mounted && msg != null) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter email first');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _magicLink() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter email first');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOtp(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Magic link sent — check email')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    logSupabaseConfig('login');
    debugPrint('[auth/login] email=${_email.text.trim()}');
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      debugPrint(
        '[auth/login] ok uid=${Supabase.instance.client.auth.currentUser?.id}',
      );
      _goAfterAuth();
    } on AuthException catch (e) {
      debugPrint(
        '[auth/login] AuthException status=${e.statusCode} msg=${e.message}',
      );
      logSupabaseConfig('login-fail');
      final hint = supabaseConfigHint;
      if (mounted) setState(() => _error = hint ?? e.message);
    } catch (e, st) {
      debugPrint('[auth/login] error=$e');
      debugPrint('[auth/login] stack=$st');
      logSupabaseConfig('login-fail');
      if (mounted) setState(() => _error = supabaseConfigHint ?? e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'ROS',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: RosColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 40,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Staff sign in',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 40),
                    FilledButton(
                      onPressed: _busy ? null : _google,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: RosColors.onPrimary,
                              ),
                            )
                          : const Text('Continue with Google'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: RosColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(
                              () => _emailExpanded = !_emailExpanded,
                            ),
                      child: Text(
                        _emailExpanded
                            ? 'Hide email sign in'
                            : 'Use email instead',
                      ),
                    ),
                    if (_emailExpanded) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_busy) _submit();
                        },
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _forgot,
                          child: const Text('Forgot password'),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _magicLink,
                        child: const Text('Email magic link'),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _busy ? null : _submit,
                        child: const Text('Sign in'),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      RosErrorText(_error!),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        final invite = _pendingInvite;
                        context.push(
                          invite == null || invite.isEmpty
                              ? '/signup'
                              : '/signup?invite=${Uri.encodeComponent(invite)}',
                        );
                      },
                child: const Text('Create account'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        final invite = _pendingInvite;
                        context.go(
                          invite == null || invite.isEmpty
                              ? '/join'
                              : '/join?code=${Uri.encodeComponent(invite)}',
                        );
                      },
                child: const Text('Have an invite code?'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
