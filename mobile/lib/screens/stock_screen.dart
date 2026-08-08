import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/errors.dart';
import '../providers/connectivity.dart';
import '../providers/stall.dart';
import '../widgets/menu_item_sheet.dart';
import '../widgets/ros_ui.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('menu_item')
          .select('id, name, price, is_available, image_url, category_id')
          .eq('stall_id', stallId)
          .order('name');
      final cats = await Supabase.instance.client
          .from('category')
          .select('id, name')
          .eq('stall_id', stallId)
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(rows as List);
        _categories = List<Map<String, dynamic>>.from(cats as List);
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

  Future<void> _toggle(String id, bool next) async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot update stock')),
      );
      return;
    }
    try {
      await Supabase.instance.client
          .from('menu_item')
          .update({'is_available': next})
          .eq('id', id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapError(e))));
    }
  }

  Future<void> _editItem(Map<String, dynamic>? existing) async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot edit the menu')),
      );
      return;
    }
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MenuItemSheet(
        stallId: stallId,
        existing: existing,
        categories: _categories,
      ),
    );
    if (saved == true) await _load();
  }

  /// Items grouped under category headers, flattened for one ListView:
  /// a `String` entry is a header, a `Map` entry is an item. Uncategorised
  /// items land in a trailing group so nothing can go missing.
  List<Object> get _rows {
    if (_categories.isEmpty) return List<Object>.from(_items);
    final rows = <Object>[];
    for (final c in _categories) {
      final inCat = [
        for (final i in _items)
          if (i['category_id'] == c['id']) i,
      ];
      if (inCat.isEmpty) continue;
      rows.add(c['name'] as String);
      rows.addAll(inCat);
    }
    final loose = [
      for (final i in _items)
        if (i['category_id'] == null ||
            !_categories.any((c) => c['id'] == i['category_id']))
          i,
    ];
    if (loose.isNotEmpty) {
      if (rows.isNotEmpty) rows.add('Uncategorised');
      rows.addAll(loose);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _editItem(null),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            )
          : null,
      body: _loading
          ? const RosLoading()
          : _error != null
          ? RosEmpty(message: _error!)
          : _items.isEmpty
          ? const RosEmpty(message: 'No menu items yet.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final entry = _rows[i];
                if (entry is String) {
                  return Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 8, bottom: 4),
                    child: Text(
                      entry,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  );
                }
                final item = entry as Map<String, dynamic>;
                final available = item['is_available'] as bool? ?? true;
                final imageUrl = item['image_url'] as String?;
                return RosSurfaceCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      if (imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                      Expanded(
                        child: SwitchListTile(
                          title: Text(item['name'] as String),
                          subtitle: MoneyText((item['price'] as num)),
                          value: available,
                          onChanged: (v) => _toggle(item['id'] as String, v),
                        ),
                      ),
                      if (canManage)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editItem(item),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
