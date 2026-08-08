import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/connectivity.dart';
import '../providers/stall.dart';
import '../services/errors.dart';
import '../services/upi.dart';
import '../widgets/ros_ui.dart';

/// Stall name, open/closed, and UPI collection details.
/// Exists on mobile because checkout renders its QR from `upi_vpa`: a wrong
/// VPA mid-service used to need a laptop to fix.
/// RLS (`stall_owner_can_update`) allows owner and manager, so this does too —
/// note the web admin is stricter and shows its settings page to owners only.
class StallSettingsScreen extends ConsumerStatefulWidget {
  const StallSettingsScreen({super.key});

  @override
  ConsumerState<StallSettingsScreen> createState() =>
      _StallSettingsScreenState();
}

class _StallSettingsScreenState extends ConsumerState<StallSettingsScreen> {
  final _name = TextEditingController();
  final _vpa = TextEditingController();
  final _payee = TextEditingController();
  var _isOpen = true;
  var _loading = true;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _vpa.dispose();
    _payee.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('stall')
          .select('name, is_open, upi_vpa, upi_payee_name')
          .eq('id', stallId)
          .single();
      if (!mounted) return;
      setState(() {
        _name.text = row['name'] as String? ?? '';
        _vpa.text = row['upi_vpa'] as String? ?? '';
        _payee.text = row['upi_payee_name'] as String? ?? '';
        _isOpen = row['is_open'] as bool? ?? true;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapError(e);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot save settings')),
      );
      return;
    }
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Stall name is required');
      return;
    }
    final vpa = _vpa.text.trim();
    if (vpa.isNotEmpty && !isValidVpa(vpa)) {
      setState(() => _error = 'UPI ID should look like name@bank');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client
          .from('stall')
          .update({
            'name': name,
            'is_open': _isOpen,
            'upi_vpa': vpa.isEmpty ? null : vpa,
            'upi_payee_name': _payee.text.trim().isEmpty
                ? null
                : _payee.text.trim(),
          })
          .eq('id', stallId);
      ref.invalidate(membershipsProvider); // stall name shows in the switcher
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapError(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageProvider);
    final vpa = _vpa.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Stall settings')),
      body: _loading
          ? const RosLoading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!canManage)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('View only — owner or manager can edit.'),
                  ),
                RosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _name,
                        enabled: canManage,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Stall name',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isOpen,
                        onChanged: canManage
                            ? (v) => setState(() => _isOpen = v)
                            : null,
                        title: const Text('Accepting orders'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                RosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'UPI collection',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Used for the QR at checkout. From Paytm Business or '
                        'any UPI app, e.g. merchant@paytm',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _vpa,
                        enabled: canManage,
                        autocorrect: false,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'UPI ID (VPA)',
                          hintText: 'merchant@paytm',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _payee,
                        enabled: canManage,
                        decoration: const InputDecoration(
                          labelText: 'Payee name',
                          hintText: 'Shown in the payer’s UPI app',
                        ),
                      ),
                      if (vpa.isEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'No UPI ID set — the checkout QR is unavailable and '
                          'only cash and card can be collected.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  RosErrorText(_error!),
                ],
                if (canManage) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Saving…' : 'Save changes'),
                  ),
                ],
              ],
            ),
    );
  }
}
