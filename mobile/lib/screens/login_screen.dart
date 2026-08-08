import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
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
  String? _error;

  String? get _pendingInvite =>
      GoRouterState.of(context).uri.queryParameters['invite'];

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
      if (!mounted) return;
      final invite = _pendingInvite;
      context.go(
        invite == null || invite.isEmpty
            ? '/'
            : '/join?code=${Uri.encodeComponent(invite)}',
      );
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
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: RosColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 40,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Staff login',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 40),
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
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      RosErrorText(_error!),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RosColors.onPrimary,
                          ),
                        )
                      : const Text('Sign in'),
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
                onPressed: () {
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
