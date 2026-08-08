import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/acting_user.dart';
import '../providers/stall.dart';
import '../services/errors.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pin = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final stallId = ref.read(activeStallIdProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (stallId == null || userId == null) return;
    final pin = _pin.text.trim();
    if (pin.length != 4) {
      setState(() => _error = 'Enter 4-digit PIN');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await Supabase.instance.client.rpc('verify_staff_pin', params: {
        'p_stall_id': stallId,
        'p_user_id': userId,
        'p_pin': pin,
      });
      if (ok != true) {
        setState(() {
          _error = 'Wrong PIN';
          _busy = false;
        });
        return;
      }
      ref.read(actingUserProvider.notifier).unlock(userId);
      if (mounted) context.go('/');
    } catch (e) {
      setState(() {
        _error = mapError(e);
        _busy = false;
      });
    }
  }

  Future<void> _setPin() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    final pin = _pin.text.trim();
    if (pin.length != 4) {
      setState(() => _error = 'PIN must be 4 digits');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc('set_staff_pin', params: {
        'p_stall_id': stallId,
        'p_pin': pin,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN saved')),
        );
      }
      setState(() => _busy = false);
    } catch (e) {
      setState(() {
        _error = mapError(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Device locked',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Enter staff PIN to continue',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              TextField(
                controller: _pin,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'PIN'),
                onSubmitted: (_) => _unlock(),
              ),
              if (_error != null)
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _unlock,
                child: const Text('Unlock'),
              ),
              TextButton(
                onPressed: _busy ? null : _setPin,
                child: const Text('Set / update my PIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
