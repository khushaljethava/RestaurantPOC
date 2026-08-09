import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../theme/ros_theme.dart';
import 'ros_ui.dart';
import '../services/errors.dart';

/// Create or edit a menu item with an optional multi-image gallery.
/// Storage path: `{stall_id}/{item_id}/{image_id}.ext` in the `menu-images`
/// bucket. Cover `menu_item.image_url` is synced by a DB trigger.
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
  static const _maxImages = 8;

  late final TextEditingController _name;
  late final TextEditingController _price;
  late bool _available;
  String? _categoryId;
  List<Map<String, dynamic>> _images = [];
  final _pending = <XFile>[];
  var _busy = false;
  String? _error;

  int get _imageCount => _images.length + _pending.length;
  bool get _atMax => _imageCount >= _maxImages;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImages());
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    if (widget.existing == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('menu_item_image')
          .select('id, url, sort_order')
          .eq('menu_item_id', widget.existing!['id'] as String)
          .order('sort_order');
      if (!mounted) return;
      setState(() => _images = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      // Gallery table may not be migrated yet — edit still works without photos.
      if (!mounted) return;
      setState(() => _images = []);
    }
  }

  Future<void> _deleteItem() async {
    final id = widget.existing?['id'] as String?;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove menu item?'),
        content: Text(
          '“${_name.text.trim().isEmpty ? 'This item' : _name.text.trim()}” '
          'will be removed from the menu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.from('menu_item').delete().eq('id', id);
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

  Future<void> _pick(ImageSource source) async {
    if (_atMax) return;
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: 1280,
      maxHeight: 1280,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          toolbarColor: RosColors.primary,
          toolbarWidgetColor: RosColors.onPrimary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: true,
          aspectRatioPresets: [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(
          title: 'Crop photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPresets: [CropAspectRatioPreset.square],
        ),
      ],
    );
    if (cropped == null || !mounted) return;
    setState(() => _pending.add(XFile(cropped.path)));
  }

  String _safeExt(String path) {
    final ext = path.split('.').last.toLowerCase();
    return RegExp(r'^[a-z0-9]+$').hasMatch(ext) ? ext : 'jpg';
  }

  Future<int> _nextSortOrder(String itemId) async {
    final rows = await Supabase.instance.client
        .from('menu_item_image')
        .select('sort_order')
        .eq('menu_item_id', itemId)
        .order('sort_order', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 0;
    return (rows.first['sort_order'] as int) + 1;
  }

  Future<void> _uploadPending(String itemId, XFile file) async {
    final imageId = const Uuid().v4();
    final safeExt = _safeExt(file.path);
    final path = '${widget.stallId}/$itemId/$imageId.$safeExt';
    final storage = Supabase.instance.client.storage.from('menu-images');
    await storage.upload(
      path,
      File(file.path),
      fileOptions: const FileOptions(upsert: false),
    );
    final url =
        '${storage.getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
    final sortOrder = await _nextSortOrder(itemId);
    try {
      await Supabase.instance.client.from('menu_item_image').insert({
        'id': imageId,
        'menu_item_id': itemId,
        'url': url,
        'sort_order': sortOrder,
      });
    } catch (e) {
      await storage.remove([path]);
      rethrow;
    }
  }

  Future<void> _deleteImage(String imageId) async {
    final itemId = widget.existing!['id'] as String;
    final row = _images.firstWhere((r) => r['id'] == imageId);
    final url = row['url'] as String;
    const marker = '/menu-images/';
    final idx = url.indexOf(marker);
    if (idx >= 0) {
      final storagePath = url.substring(idx + marker.length).split('?').first;
      try {
        await Supabase.instance.client.storage
            .from('menu-images')
            .remove([storagePath]);
      } catch (_) {}
    }
    await Supabase.instance.client
        .from('menu_item_image')
        .delete()
        .eq('id', imageId);
    final rest = await Supabase.instance.client
        .from('menu_item_image')
        .select('id')
        .eq('menu_item_id', itemId)
        .order('sort_order');
    for (var i = 0; i < rest.length; i++) {
      await Supabase.instance.client
          .from('menu_item_image')
          .update({'sort_order': i + 1000})
          .eq('id', rest[i]['id']);
    }
    for (var i = 0; i < rest.length; i++) {
      await Supabase.instance.client
          .from('menu_item_image')
          .update({'sort_order': i})
          .eq('id', rest[i]['id']);
    }
    await _loadImages();
  }

  void _removePending(int index) => setState(() => _pending.removeAt(index));

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
      for (final file in _pending) {
        await _uploadPending(itemId, file);
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

  Future<void> _onDeleteExisting(String imageId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _deleteImage(imageId);
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapError(e);
        _busy = false;
      });
    }
  }

  Widget _thumb({required Widget child, VoidCallback? onDelete}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 64, height: 64, child: child),
          ),
          if (onDelete != null)
            Positioned(
              top: -6,
              right: -6,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  minimumSize: const Size(24, 24),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                onPressed: _busy ? null : onDelete,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final base = Theme.of(context);
    final sheetTheme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        surface: RosColors.auroraMid,
        onSurface: RosColors.onSurface,
        onSurfaceVariant: RosColors.onSurfaceVariant,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: RosColors.onSurface,
        displayColor: RosColors.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: RosColors.onSurfaceVariant),
        floatingLabelStyle: const TextStyle(color: RosColors.primary),
        hintStyle: const TextStyle(color: RosColors.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RosColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RosColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RosColors.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: RosColors.onSurface,
        iconColor: RosColors.onSurfaceVariant,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RosColors.primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: RosColors.outlineVariant),
        ),
      ),
    );

    return Theme(
      data: sheetTheme,
      child: Material(
        color: RosColors.auroraMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(context).height * 0.85 - bottomInset,
              ),
              child: SingleChildScrollView(
                child: DefaultTextStyle(
                  style: sheetTheme.textTheme.bodyLarge!.copyWith(
                    color: RosColors.onSurface,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.existing == null ? 'Add item' : 'Edit item',
                        style: sheetTheme.textTheme.titleLarge?.copyWith(
                              color: RosColors.primary,
                              fontWeight: FontWeight.w700,
                            ) ??
                            const TextStyle(
                              color: RosColors.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        style: const TextStyle(color: RosColors.onSurface),
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _price,
                        style: const TextStyle(color: RosColors.onSurface),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Price'),
                      ),
                      if (widget.categories.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: DropdownButtonFormField<String?>(
                            initialValue: _categoryId,
                            style: const TextStyle(color: RosColors.onSurface),
                            dropdownColor: Colors.white,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: [
                              const DropdownMenuItem(
                                child: Text('No category'),
                              ),
                              for (final c in widget.categories)
                                DropdownMenuItem(
                                  value: c['id'] as String,
                                  child: Text(c['name'] as String),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _categoryId = v),
                          ),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _available,
                        onChanged: (v) => setState(() => _available = v),
                        title: const Text(
                          'Available',
                          style: TextStyle(color: RosColors.onSurface),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Photos ($_imageCount/$_maxImages)',
                        style: sheetTheme.textTheme.titleSmall?.copyWith(
                              color: RosColors.onSurface,
                              fontWeight: FontWeight.w600,
                            ) ??
                            const TextStyle(
                              color: RosColors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length + _pending.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            if (i < _images.length) {
                              final row = _images[i];
                              return _thumb(
                                child: CachedNetworkImage(
                                  imageUrl: row['url'] as String,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      const Icon(Icons.broken_image),
                                ),
                                onDelete: () => _onDeleteExisting(
                                  row['id'] as String,
                                ),
                              );
                            }
                            final file = _pending[i - _images.length];
                            return _thumb(
                              child: Image.file(
                                File(file.path),
                                fit: BoxFit.cover,
                              ),
                              onDelete: () =>
                                  _removePending(i - _images.length),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy || _atMax
                                  ? null
                                  : () => _pick(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy || _atMax
                                  ? null
                                  : () => _pick(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                            ),
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
                      if (widget.existing != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : _deleteItem,
                          style: TextButton.styleFrom(
                            foregroundColor: RosColors.error,
                          ),
                          child: const Text('Remove item'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
