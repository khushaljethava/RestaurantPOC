import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ros_ui.dart';
import '../services/errors.dart';

/// Create or edit a menu item, with optional image.
/// Storage path mirrors the web admin (`<stall_id>/<item_id>.<ext>` in the
/// `menu-images` bucket) so both clients overwrite the same object.
class MenuItemSheet extends StatefulWidget {
  const MenuItemSheet({
    super.key,
    required this.stallId,
    this.existing,
    this.categories = const [],
  });

  final String stallId;
  final Map<String, dynamic>? existing;

  /// `category` rows `{id, name}` for this stall, in sort order. Categories
  /// are created on the web admin; mobile only assigns an item to one.
  final List<Map<String, dynamic>> categories;

  @override
  State<MenuItemSheet> createState() => _MenuItemSheetState();
}

class _MenuItemSheetState extends State<MenuItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late bool _available;
  String? _categoryId;
  XFile? _picked;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: (e?['name'] as String?) ?? '');
    _price = TextEditingController(
      text: e == null ? '' : (e['price'] as num).toString(),
    );
    _available = e == null || e['is_available'] == true;
    _categoryId = e?['category_id'] as String?;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    // Downscale on device: originals off a phone camera blow past the
    // bucket's file_size_limit and cost users mobile data on every menu load.
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (file != null) setState(() => _picked = file);
  }

  /// Uploads [_picked] for [itemId] and returns its public URL.
  Future<String> _uploadImage(String itemId) async {
    final file = _picked!;
    final ext = file.path.split('.').last.toLowerCase();
    final safeExt = RegExp(r'^[a-z0-9]+$').hasMatch(ext) ? ext : 'jpg';
    final path = '${widget.stallId}/$itemId.$safeExt';
    final storage = Supabase.instance.client.storage.from('menu-images');
    await storage.upload(
      path,
      File(file.path),
      fileOptions: const FileOptions(upsert: true),
    );
    // Bucket is public but CDN-cached; bust it so a replaced photo shows up.
    final url = storage.getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = num.tryParse(_price.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _error = 'Price must be a number, 0 or more');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final db = Supabase.instance.client.from('menu_item');
      final values = {
        'name': name,
        'price': price,
        'is_available': _available,
        'category_id': _categoryId,
      };
      String itemId;
      if (widget.existing == null) {
        final row = await db
            .insert({...values, 'stall_id': widget.stallId})
            .select('id')
            .single();
        itemId = row['id'] as String;
      } else {
        itemId = widget.existing!['id'] as String;
        await db.update(values).eq('id', itemId);
      }
      if (_picked != null) {
        // Separate step: the item id is part of the storage path, so a new
        // item must exist before its image can be uploaded.
        final url = await _uploadImage(itemId);
        await db.update({'image_url': url}).eq('id', itemId);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapError(e);
        _busy = false;
      });
    }
  }

  Future<void> _clearImage() async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client
          .from('menu_item')
          .update({'image_url': null})
          .eq('id', widget.existing!['id'] as String);
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final existingUrl = widget.existing?['image_url'] as String?;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Add item' : 'Edit item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            if (widget.categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(child: Text('No category')),
                    for (final c in widget.categories)
                      DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _available,
              onChanged: (v) => setState(() => _available = v),
              title: const Text('Available'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_picked != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_picked!.path),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (existingUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: existingUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const Icon(Icons.broken_image),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.image),
                    label: Text(
                      _picked != null || existingUrl != null
                          ? 'Change photo'
                          : 'Add photo',
                    ),
                  ),
                ),
                if (existingUrl != null && _picked == null)
                  IconButton(
                    tooltip: 'Remove photo',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _busy ? null : _clearImage,
                  ),
              ],
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
      ),
    );
  }
}
