import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import '../l10n/app_localizations.dart';
import '../services/errors.dart';
import '../providers/cart.dart';
import '../providers/connectivity.dart';
import '../providers/shift.dart';
import '../providers/stall.dart';
import '../providers/tables.dart';
import '../theme/ros_theme.dart';
import '../widgets/glass.dart';
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
  List<Map<String, dynamic>> _categories = [];
  String? _categoryId; // null = All
  var _grid = false;
  /// Selected registered table label; null = no table (pay now / no table bill).
  String? _tableLabel;

  @override
  void initState() {
    super.initState();
    _tableLabel = widget.initialTableLabel;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      _grid = p.getBool('pos_grid') ?? false;
      await _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final stalls = await ref.read(menuStallsProvider.future);
    if (!mounted) return;
    final active = ref.read(activeStallIdProvider);
    setState(() {
      _menuStallId = stalls.isEmpty
          ? active
          : (stalls.any((s) => s.id == active) ? active : stalls.first.id);
    });
    await ref.read(cartProvider.notifier).restoreDraft();
    if (!mounted) return;
    await _loadMenu();
  }

  Future<void> _repeatLast() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    try {
      final bill = await Supabase.instance.client
          .from('bill')
          .select('id')
          .eq('collected_by_stall_id', stallId)
          .eq('status', 'paid')
          .order('paid_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (bill == null) return;
      final orders = await Supabase.instance.client
          .from('orders')
          .select('stall_id, order_item(menu_item_id, name, unit_price, qty)')
          .eq('bill_id', bill['id']);
      for (final o in orders as List) {
        for (final it in (o['order_item'] as List? ?? [])) {
          final mid = it['menu_item_id'] as String?;
          if (mid == null) continue;
          ref.read(cartProvider.notifier).add(CartLine(
            stallId: o['stall_id'] as String,
            menuItemId: mid,
            name: it['name'] as String,
            unitPrice: Money.fromRupees(it['unit_price'] as num),
            qty: (it['qty'] as num).round(),
          ));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = mapError(e));
    }
  }

  Future<void> _loadMenu() async {
    final stallId = _menuStallId;
    if (stallId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No active stall';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('menu_item')
          .select(
            'id, name, price, is_available, stall_id, image_url, category_id',
          )
          .eq('stall_id', stallId)
          .eq('is_available', true)
          .order('name');
      final cats = await Supabase.instance.client
          .from('category')
          .select('id, name')
          .eq('stall_id', stallId)
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _menu = List<Map<String, dynamic>>.from(rows as List);
        _categories = List<Map<String, dynamic>>.from(cats as List);
        // A category picked on the previous stall means nothing here.
        _categoryId = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapError(e);
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
          decoration: const InputDecoration(hintText: 'Special instructions'),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Dialog route still detaches TextField after pop — dispose next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (note == null || !mounted) return;
    ref
        .read(cartProvider.notifier)
        .setNotes(line.stallId, line.menuItemId, note);
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

    // Place-time: closed stalls + unavailable items.
    final stallIds = {for (final l in cart) l.stallId};
    final closed = <String>[];
    for (final sid in stallIds) {
      final row = await Supabase.instance.client
          .from('stall')
          .select('name, is_open')
          .eq('id', sid)
          .maybeSingle();
      if (row != null && row['is_open'] != true) {
        closed.add(row['name'] as String? ?? 'Stall');
      }
    }
    if (closed.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Closed: ${closed.join(', ')}')),
      );
      return;
    }
    final unavailable = <CartLine>[];
    for (final line in cart) {
      final row = await Supabase.instance.client
          .from('menu_item')
          .select('is_available, name')
          .eq('id', line.menuItemId)
          .maybeSingle();
      if (row != null && row['is_available'] == false) {
        unavailable.add(line);
      }
    }
    if (unavailable.isNotEmpty) {
      if (!mounted) return;
      final keep = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unavailable items'),
          content: Text(unavailable.map((l) => l.name).join(', ')),
          actions: [
            TextButton(
              onPressed: () {
                for (final l in unavailable) {
                  ref.read(cartProvider.notifier).setQty(l.stallId, l.menuItemId, 0);
                }
                Navigator.pop(ctx, false);
              },
              child: const Text('Remove'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keep (manager)'),
            ),
          ],
        ),
      );
      if (keep != true) {
        setState(() {});
        return;
      }
    }

    setState(() => _error = null);
    final tableLabel = _tableLabel;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Added to table $tableLabel')));
        context.pop();
        return;
      }

      final shift = ref.read(openShiftProvider).asData?.value;
      final billId = await Supabase.instance.client.rpc(
        'open_bill',
        params: {
          'p_collected_by_stall_id': recordedBy,
          'p_order_ids': orderIds,
          'p_idempotency_key': const Uuid().v4(),
          'p_table_label': null,
          'p_order_type': 'dine_in',
          'p_shift_id': shift?.id,
        },
      );
      if (!mounted) return;
      context.push('/checkout/$billId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mapError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartProvider.notifier).total.rupees;
    final stalls = ref.watch(menuStallsProvider).asData?.value ?? const [];
    final tableLabels = ref.watch(activeTableLabelsProvider);
    // Filtering a loaded list beats a round trip per chip tap — menus are
    // small and the counter is often on a bad connection.
    final visibleMenu = _categoryId == null
        ? _menu
        : [
            for (final m in _menu)
              if (m['category_id'] == _categoryId) m,
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newOrder),
        actions: [
          IconButton(
            tooltip: 'Repeat last',
            icon: const Icon(Icons.replay),
            onPressed: _repeatLast,
          ),
          IconButton(
            icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
            onPressed: () async {
              setState(() => _grid = !_grid);
              final p = await SharedPreferences.getInstance();
              await p.setBool('pos_grid', _grid);
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/pos/search'),
          ),
        ],
      ),
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
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: InputDecorator(
                    isEmpty: _tableLabel == null,
                    decoration: InputDecoration(
                      labelText: 'Table',
                      filled: true,
                      fillColor: Colors.white,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelStyle: const TextStyle(
                        color: RosColors.onSurfaceVariant,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: RosColors.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: RosColors.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: RosColors.primary,
                          width: 1.6,
                        ),
                      ),
                      contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        isDense: true,
                        value: (_tableLabel != null &&
                                (tableLabels.contains(_tableLabel) ||
                                    _tableLabel ==
                                        widget.initialTableLabel))
                            ? _tableLabel
                            : null,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: RosColors.onSurface,
                          fontSize: 16,
                        ),
                        hint: const Text(
                          'No table',
                          style: TextStyle(color: RosColors.onSurfaceVariant),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No table'),
                          ),
                          for (final l in tableLabels)
                            DropdownMenuItem<String?>(
                              value: l,
                              child: Text(l),
                            ),
                          if (_tableLabel != null &&
                              !tableLabels.contains(_tableLabel))
                            DropdownMenuItem<String?>(
                              value: _tableLabel,
                              child: Text(_tableLabel!),
                            ),
                        ],
                        onChanged: (v) => setState(() => _tableLabel = v),
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RosErrorText(_error!),
                  ),
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      children: [
                        for (final c in [
                          const {'id': null, 'name': 'All'},
                          ..._categories,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(c['name'] as String),
                              selected: c['id'] == _categoryId,
                              selectedColor: RosColors.primaryContainer,
                              checkmarkColor: RosColors.onPrimaryContainer,
                              side: BorderSide(
                                color: c['id'] == _categoryId
                                    ? Colors.transparent
                                    : RosColors.outlineVariant,
                              ),
                              onSelected: (_) => setState(
                                () => _categoryId = c['id'] as String?,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final menuItems = visibleMenu;
                      void addItem(Map<String, dynamic> item) {
                        final price = Money.fromRupees(
                          (item['price'] as num?) ?? 0,
                        );
                        ref.read(cartProvider.notifier).add(
                              CartLine(
                                stallId: item['stall_id'] as String? ??
                                    _menuStallId!,
                                menuItemId:
                                    (item['id'] ?? item['menu_item_id'])
                                        as String,
                                name: item['name'] as String,
                                unitPrice: price,
                                qty: 1,
                              ),
                            );
                      }

                      if (menuItems.isEmpty) {
                        return const RosEmpty(
                          message:
                              'No menu items — add some under Menu / Stock',
                        );
                      }

                      if (_grid) {
                        return GridView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: menuItems.length,
                          itemBuilder: (context, i) {
                            final item = menuItems[i];
                            final price = Money.fromRupees(
                              (item['price'] as num?) ?? 0,
                            );
                            final imageUrl = item['image_url'] as String?;
                            return RosSurfaceCard(
                              padding: EdgeInsets.zero,
                              onTap: () => addItem(item),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        top: Radius.circular(RosGlass.radius),
                                      ),
                                      child: imageUrl != null &&
                                              imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              errorWidget:
                                                  (context, url, error) =>
                                                      _thumbFallback(
                                                          fill: true),
                                            )
                                          : _thumbFallback(fill: true),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'] as String,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        MoneyText(price.rupees),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }

                      return ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: menuItems.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final item = menuItems[i];
                          final price = Money.fromRupees(
                            (item['price'] as num?) ?? 0,
                          );
                          final imageUrl = item['image_url'] as String?;
                          return RosSurfaceCard(
                            padding: const EdgeInsets.all(12),
                            onTap: () => addItem(item),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: imageUrl != null &&
                                          imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorWidget:
                                              (context, url, error) =>
                                                  _thumbFallback(),
                                        )
                                      : _thumbFallback(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item['name'] as String,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    MoneyText(price.rupees),
                                    const SizedBox(height: 4),
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor:
                                          RosColors.secondaryContainer,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        iconSize: 20,
                                        color:
                                            RosColors.onSecondaryContainer,
                                        icon: const Icon(Icons.add),
                                        onPressed: () => addItem(item),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (cart.isNotEmpty)
                  GlassBar(
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
                                      title: Text('${line.name} × ${line.qty}'),
                                      subtitle: Text(
                                        line.notes == null ||
                                                line.notes!.isEmpty
                                            ? line.lineTotal.format()
                                            : '${line.lineTotal.format()} · ${line.notes}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Note',
                                            icon: const Icon(
                                              Icons.notes,
                                              size: 20,
                                            ),
                                            onPressed: () => _editNotes(line),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                            onPressed: () => ref
                                                .read(cartProvider.notifier)
                                                .setQty(
                                                  line.stallId,
                                                  line.menuItemId,
                                                  line.qty - 1,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Total',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const Spacer(),
                                MoneyText(total),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _placeAndCheckout,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                              ),
                              child: Text(l10n.placeOrder),
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

  Widget _thumbFallback({bool fill = false}) {
    final box = Container(
      color: RosColors.surfaceDim,
      alignment: Alignment.center,
      child: const Icon(Icons.fastfood, color: RosColors.outline),
    );
    return fill ? box : SizedBox(width: 56, height: 56, child: box);
  }
}
