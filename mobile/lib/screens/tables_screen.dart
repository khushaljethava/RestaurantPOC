import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/connectivity.dart';
import '../providers/stall.dart';
import '../providers/tables.dart';
import '../widgets/ros_ui.dart';
import '../services/errors.dart';

/// Manage the stall's registered tables (owner/manager only — RLS enforces it
/// too; the UI check just avoids offering a button that would 403).
class TablesScreen extends ConsumerWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(stallTablesProvider);
    final canManage = ref.watch(canManageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tables'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(stallTablesProvider),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Add table'),
            )
          : null,
      body: tables.when(
        loading: () => const RosLoading(),
        error: (e, _) => RosErrorText(mapError(e)),
        data: (rows) {
          if (rows.isEmpty) {
            return const RosEmpty(
              message: 'No tables yet. Add one to use table service.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final t = rows[i];
              final active = t['is_active'] == true;
              final seats = t['seats'] as int?;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RosSurfaceCard(
                  onTap: canManage ? () => _edit(context, ref, t) : null,
                  child: Row(
                    children: [
                      Icon(
                        Icons.table_restaurant,
                        color: active ? null : Theme.of(context).disabledColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t['label'] as String,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                decoration: active
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                        ),
                      ),
                      if (seats != null)
                        Text(
                          '$seats seats',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (canManage) const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? existing,
  ) async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot edit tables')),
      );
      return;
    }
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TableSheet(stallId: stallId, existing: existing),
    );
    if (saved == true) ref.invalidate(stallTablesProvider);
  }
}

class _TableSheet extends StatefulWidget {
  const _TableSheet({required this.stallId, this.existing});

  final String stallId;
  final Map<String, dynamic>? existing;

  @override
  State<_TableSheet> createState() => _TableSheetState();
}

class _TableSheetState extends State<_TableSheet> {
  late final TextEditingController _label;
  late final TextEditingController _seats;
  late bool _active;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: (e?['label'] as String?) ?? '');
    _seats = TextEditingController(
      text: (e?['seats'] as int?)?.toString() ?? '',
    );
    _active = e == null || e['is_active'] == true;
  }

  @override
  void dispose() {
    _label.dispose();
    _seats.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Label is required');
      return;
    }
    final seats = int.tryParse(_seats.text.trim());
    if (_seats.text.trim().isNotEmpty && (seats == null || seats <= 0)) {
      setState(() => _error = 'Seats must be a positive number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final values = {'label': label, 'seats': seats, 'is_active': _active};
      final db = Supabase.instance.client.from('restaurant_table');
      if (widget.existing == null) {
        await db.insert({...values, 'stall_id': widget.stallId});
      } else {
        await db.update(values).eq('id', widget.existing!['id'] as String);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // 23505 (unique stall_id+label) is the common failure here, and
        // mapError's generic "That already exists" loses which table.
        _error = e is PostgrestException && e.code == '23505'
            ? 'A table called "$label" already exists'
            : mapError(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Add table' : 'Edit table',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'T1',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _seats,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Seats (optional)'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: const Text('Active'),
            subtitle: const Text('Inactive tables are hidden from the POS'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            RosErrorText(_error!),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
