import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../providers/cart.dart';
import '../providers/connectivity.dart';
import '../providers/stall.dart';
import '../theme/ros_theme.dart';
import '../widgets/ros_ui.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key, this.initialTableLabel});

  final String? initialTableLabel;

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  List<Map<String, dynamic>> _menu = [];
  var _loading = true;
  String? _error;
  String? _menuStallId;
  late final TextEditingController _table;

  @override
  void initState() {
    super.initState();
    _table = TextEditingController(text: widget.initialTableLabel ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final stalls = await ref.read(menuStallsProvider.future);
    final active = ref.read(activeStallIdProvider);
    setState(() {
      _menuStallId = stalls.isEmpty
          ? active
          : (stalls.any((s) => s.id == active)
              ? active
              : stalls.first.id);
    });
    await _loadMenu();
  }

  Future<void> _loadMenu() async {
    final stallId = _menuStallId;
    if (stallId == null) {
      setState(() {
        _loading = false;
        _error = 'No active stall';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('menu_item')
          .select('id, name, price, is_available, stall_id, image_url')
          .eq('stall_id', stallId)
          .eq('is_available', true)
          .order('name');
      setState(() {
        _menu = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _editNotes(CartLine line) async {
    final ctrl = TextEditingController(text: line.notes ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Note · ${line.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Special instructions',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (note == null || !mounted) return;
    ref.read(cartProvider.notifier).setNotes(line.stallId, line.menuItemId, note);
  }

  Future<void> _hold() async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot place orders')),
      );
      return;
    }
    final recordedBy = ref.read(activeStallIdProvider);
    final cart = ref.read(cartProvider);
    if (recordedBy == null || cart.isEmpty) return;

    final stalls = cart.map((e) => e.stallId).toSet();
    if (stalls.length > 1 || stalls.single != recordedBy) {
      setState(() =>
          _error = 'Hold only supports items from your own stall');
      return;
    }

    setState(() => _error = null);
    try {
      await Supabase.instance.client.rpc(
        'create_order',
        params: {
          'p_stall_id': recordedBy,
          'p_recorded_by_stall_id': recordedBy,
          'p_idempotency_key': const Uuid().v4(),
          'p_status': 'held',
          'p_items':
              ref.read(cartProvider.notifier).toRpcItemsByStall()[recordedBy],
          'p_table_label':
              _table.text.trim().isEmpty ? null : _table.text.trim(),
        },
      );
      ref.read(cartProvider.notifier).clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Held')));
        context.pop();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _placeAndCheckout() async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot place orders')),
      );
      return;
    }
    final recordedBy = ref.read(activeStallIdProvider);
    final cart = ref.read(cartProvider);
    if (recordedBy == null || cart.isEmpty) return;

    setState(() => _error = null);
    final tableLabel =
        _table.text.trim().isEmpty ? null : _table.text.trim();
    try {
      final byStall = ref.read(cartProvider.notifier).toRpcItemsByStall();
      final orderIds = <String>[];
      for (final entry in byStall.entries) {
        final id = await Supabase.instance.client.rpc(
          'create_order',
          params: {
            'p_stall_id': entry.key,
            'p_recorded_by_stall_id': recordedBy,
            'p_idempotency_key': const Uuid().v4(),
            'p_status': 'pending',
            'p_items': entry.value,
            'p_table_label': tableLabel,
          },
        );
        orderIds.add(id as String);
      }

      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;

      if (tableLabel != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to table $tableLabel')),
        );
        context.pop();
        return;
      }

      final billId = await Supabase.instance.client.rpc(
        'open_bill',
        params: {
          'p_collected_by_stall_id': recordedBy,
          'p_order_ids': orderIds,
          'p_idempotency_key': const Uuid().v4(),
          'p_table_label': null,
        },
      );
      if (!mounted) return;
      context.push('/checkout/$billId');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _table.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = cart.fold<double>(0, (s, e) => s + e.lineTotal);
    final stalls = ref.watch(menuStallsProvider).asData?.value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('New order')),
      body: _loading && _menu.isEmpty
          ? const RosLoading()
          : Column(
              children: [
                if (stalls.length > 1)
                  Container(
                    color: RosColors.surfaceContainerLow,
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      children: [
                        for (final s in stalls)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(s.name),
                              selected: s.id == _menuStallId,
                              selectedColor: RosColors.primaryContainer,
                              checkmarkColor: RosColors.onPrimaryContainer,
                              labelStyle: TextStyle(
                                color: s.id == _menuStallId
                                    ? RosColors.onPrimaryContainer
                                    : RosColors.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                              side: BorderSide(
                                color: s.id == _menuStallId
                                    ? Colors.transparent
                                    : RosColors.outlineVariant,
                              ),
                              onSelected: (_) {
                                setState(() => _menuStallId = s.id);
                                _loadMenu();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _table,
                    decoration: const InputDecoration(
                      labelText: 'Table label (optional)',
                      border: UnderlineInputBorder(),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: RosColors.outlineVariant),
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RosErrorText(_error!),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _menu.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = _menu[i];
                      final price = (item['price'] as num).toDouble();
                      final stallId =
                          item['stall_id'] as String? ?? _menuStallId!;
                      final imageUrl = item['image_url'] as String?;
                      return RosSurfaceCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () {
                          ref.read(cartProvider.notifier).add(
                                CartLine(
                                  stallId: stallId,
                                  menuItemId: item['id'] as String,
                                  name: item['name'] as String,
                                  unitPrice: price,
                                  qty: 1,
                                ),
                              );
                        },
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          _thumbFallback(),
                                    )
                                  : _thumbFallback(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item['name'] as String,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                MoneyText(price),
                                const SizedBox(height: 4),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: RosColors.secondaryContainer,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    iconSize: 20,
                                    color: RosColors.onSecondaryContainer,
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      ref.read(cartProvider.notifier).add(
                                            CartLine(
                                              stallId: stallId,
                                              menuItemId: item['id'] as String,
                                              name: item['name'] as String,
                                              unitPrice: price,
                                              qty: 1,
                                            ),
                                          );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (cart.isNotEmpty)
                  Material(
                    color: RosColors.surfaceContainer,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 160),
                              child: ListView(
                                shrinkWrap: true,
                                children: [
                                  for (final line in cart)
                                    ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      onLongPress: () => _editNotes(line),
                                      title: Text(
                                          '${line.name} × ${line.qty}'),
                                      subtitle: Text(
                                        line.notes == null ||
                                                line.notes!.isEmpty
                                            ? formatInr(line.lineTotal)
                                            : '${formatInr(line.lineTotal)} · ${line.notes}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Note',
                                            icon: const Icon(Icons.notes,
                                                size: 20),
                                            onPressed: () =>
                                                _editNotes(line),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.remove_circle_outline),
                                            onPressed: () => ref
                                                .read(cartProvider.notifier)
                                                .setQty(
                                                    line.stallId,
                                                    line.menuItemId,
                                                    line.qty - 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Text('Total',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const Spacer(),
                                MoneyText(total),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _hold,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize:
                                          const Size.fromHeight(56),
                                    ),
                                    child: const Text('Hold'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _placeAndCheckout,
                                    child: const Text('Place order'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      width: 56,
      height: 56,
      color: RosColors.surfaceDim,
      child: const Icon(Icons.fastfood, color: RosColors.outline),
    );
  }
}
