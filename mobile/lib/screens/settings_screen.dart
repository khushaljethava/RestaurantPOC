import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  var _sound = true;
  var _vibrate = true;
  var _keepAwake = false;
  var _orderType = 'dine_in';
  var _textScale = 1.0;
  var _lang = 'en';
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _sound = p.getBool('settings_sound') ?? true;
      _vibrate = p.getBool('settings_vibrate') ?? true;
      _keepAwake = p.getBool('settings_keep_awake') ?? false;
      _orderType = p.getString('settings_order_type') ?? 'dine_in';
      _textScale = p.getDouble('settings_text_scale') ?? 1.0;
      _lang = p.getString('settings_lang') ?? 'en';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('settings_sound', _sound);
    await p.setBool('settings_vibrate', _vibrate);
    await p.setBool('settings_keep_awake', _keepAwake);
    await p.setString('settings_order_type', _orderType);
    await p.setDouble('settings_text_scale', _textScale);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Sound'),
            value: _sound,
            onChanged: (v) { setState(() => _sound = v); _save(); },
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            value: _vibrate,
            onChanged: (v) { setState(() => _vibrate = v); _save(); },
          ),
          SwitchListTile(
            title: const Text('Keep awake (stall mode)'),
            value: _keepAwake,
            onChanged: (v) { setState(() => _keepAwake = v); _save(); },
          ),
          ListTile(
            title: const Text('Default order type'),
            subtitle: Text(_orderType),
            onTap: () async {
              final v = await showDialog<String>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Order type'),
                  children: [
                    for (final t in ['dine_in', 'takeaway', 'parcel'])
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, t),
                        child: Text(t),
                      ),
                  ],
                ),
              );
              if (v != null) {
                setState(() => _orderType = v);
                _save();
              }
            },
          ),
          ListTile(
            title: const Text('Text size'),
            subtitle: Text(_textScale == 1.0
                ? 'Normal'
                : _textScale < 1.5
                    ? 'Large'
                    : 'Extra'),
            onTap: () {
              setState(() {
                if (_textScale < 1.2) {
                  _textScale = 1.3;
                } else if (_textScale < 1.6) {
                  _textScale = 1.8;
                } else {
                  _textScale = 1.0;
                }
              });
              _save();
            },
          ),
          ListTile(
            title: const Text('Language'),
            subtitle: Text(_lang),
            onTap: () async {
              final v = await showDialog<String>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Language'),
                  children: [
                    for (final t in ['en', 'hi', 'gu'])
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, t),
                        child: Text(t == 'en' ? 'English' : t == 'hi' ? 'हिन्दी' : 'ગુજરાતી'),
                      ),
                  ],
                ),
              );
              if (v != null) {
                setState(() => _lang = v);
                final p = await SharedPreferences.getInstance();
                await p.setString('settings_lang', v);
              }
            },
          ),
          ListTile(
            title: const Text('Device mode'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/device'),
          ),
          ListTile(
            title: const Text('Lock now'),
            onTap: () => context.go('/lock'),
          ),
          ListTile(
            title: const Text('Help'),
            onTap: () => context.push('/help'),
          ),
        ],
      ),
    );
  }
}
