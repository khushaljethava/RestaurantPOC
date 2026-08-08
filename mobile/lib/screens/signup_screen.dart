import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/errors.dart';
import '../config.dart';
import '../theme/ros_theme.dart';
import '../widgets/ros_ui.dart';

/// Create-account screen (split from login per stitch sign_up).
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
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
    logSupabaseConfig('signup');
    debugPrint('[auth/signup] email=${_email.text.trim()}');
    try {
      await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
      debugPrint(
        '[auth/signup] ok uid=${Supabase.instance.client.auth.currentUser?.id}',
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
        '[auth/signup] AuthException status=${e.statusCode} msg=${e.message}',
      );
      logSupabaseConfig('signup-fail');
      if (mounted) setState(() => _error = e.message);
    } catch (e, st) {
      debugPrint('[auth/signup] error=$e\n$st');
      logSupabaseConfig('signup-fail');
      if (mounted) setState(() => _error = mapError(e));
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
                    TextButton(
                      onPressed: () {
                        final invite = _pendingInvite;
                        context.go(
                          invite == null || invite.isEmpty
                              ? '/login'
                              : '/login?invite=${Uri.encodeComponent(invite)}',
                        );
                      },
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                      ),
                      child: const Text('← Back to sign in'),
                    ),
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
                      'Create an account',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 32),
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
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
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
                      : const Text('Create account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
