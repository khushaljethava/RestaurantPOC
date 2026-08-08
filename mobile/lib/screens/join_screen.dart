import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/errors.dart';
import '../config.dart';
import '../invite_code.dart';
import '../providers/stall.dart';
import '../theme/ros_theme.dart';
import '../widgets/ros_ui.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final TextEditingController _code;
  var _busy = false;
  String? _error;
  var _didAutoRedeem = false;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.initialCode ?? '');
    if (widget.initialCode != null &&
        widget.initialCode!.trim().isNotEmpty &&
        Supabase.instance.client.auth.currentSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoRedeemOnce());
    }
  }

  Future<void> _autoRedeemOnce() async {
    if (_didAutoRedeem || !mounted) return;
    _didAutoRedeem = true;
    await _redeem();
  }

  Future<void> _redeem() async {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    final code = normalizeInviteCode(_code.text);
    if (code.isEmpty) {
      setState(() => _error = 'Enter an invite code');
      return;
    }
    if (!loggedIn) {
      // Query param is required: auth redirect races LoginScreen dispose.
      context.go('/login?invite=${Uri.encodeComponent(code)}');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    logSupabaseConfig('join');
    debugPrint('[auth/join] redeem code=$code');
    try {
      final stallId = await Supabase.instance.client.rpc(
        'redeem_stall_invite',
        params: {'p_code': code},
      );
      debugPrint('[auth/join] ok stallId=$stallId');
      ref.invalidate(membershipsProvider);
      if (stallId is String && stallId.isNotEmpty) {
        ref.read(activeStallOverrideProvider.notifier).set(stallId);
      }
      if (mounted) context.go('/');
    } on PostgrestException catch (e) {
      debugPrint(
        '[auth/join] PostgrestException code=${e.code} msg=${e.message}',
      );
      logSupabaseConfig('join-fail');
      if (mounted) setState(() => _error = e.message);
    } catch (e, st) {
      debugPrint('[auth/join] error=$e\n$st');
      logSupabaseConfig('join-fail');
      if (mounted) setState(() => _error = mapError(e));
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
          onPressed: () => loggedIn ? context.pop() : context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'Enter invite code',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loggedIn
                          ? 'Redeem a stall invite to get access.'
                          : 'Sign in next, then we join with this code.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
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
                      onSubmitted: (_) {
                        if (!_busy) _redeem();
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      RosErrorText(_error!),
                    ],
                  ],
                ),
              ),
              // Avoid nested SafeArea from RosBottomCta eating the tap target.
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                child: FilledButton(
                  onPressed: _busy ? null : _redeem,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RosColors.onPrimary,
                          ),
                        )
                      : Text(loggedIn ? 'Join' : 'Continue'),
                ),
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
