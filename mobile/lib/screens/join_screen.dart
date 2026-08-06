import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/stall.dart';
import '../widgets/ros_ui.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _code = TextEditingController();
  var _busy = false;
  String? _error;

  Future<void> _redeem() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'redeem_stall_invite',
        params: {'p_code': _code.text.trim().toUpperCase()},
      );
      ref.invalidate(membershipsProvider);
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join stall'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              loggedIn ? context.pop() : context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter invite code',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                loggedIn
                    ? 'Redeem a stall invite to get access.'
                    : 'Sign in first, then return here with your invite code.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 4,
                ),
                decoration: const InputDecoration(
                  labelText: 'Invite code',
                  hintText: 'ABCD-1234',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                RosErrorText(_error!),
              ],
              const Spacer(),
              RosBottomCta(
                label: 'Join',
                busy: _busy,
                enabled: loggedIn,
                onPressed: _redeem,
              ),
              if (!loggedIn)
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to login'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
