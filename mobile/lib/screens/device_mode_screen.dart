import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceModeScreen extends StatefulWidget {
  const DeviceModeScreen({super.key});

  @override
  State<DeviceModeScreen> createState() => _DeviceModeScreenState();
}

class _DeviceModeScreenState extends State<DeviceModeScreen> {
  String _mode = 'counter';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() => _mode = p.getString('device_mode') ?? 'counter');
    });
  }

  Future<void> _set(String mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('device_mode', mode);
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device mode')),
      body: Column(
        children: [
          RadioListTile<String>(
            title: const Text('Counter'),
            subtitle: const Text('Default landing: POS'),
            value: 'counter',
            groupValue: _mode,
            onChanged: (v) => _set(v!),
          ),
          RadioListTile<String>(
            title: const Text('Stall screen'),
            subtitle: const Text('Default landing: Stall board, keep-awake'),
            value: 'stall',
            groupValue: _mode,
            onChanged: (v) => _set(v!),
          ),
        ],
      ),
    );
  }
}
