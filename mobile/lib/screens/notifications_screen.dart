import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('local_alerts') ?? [];
    setState(() {
      _items = raw
          .map((e) => Map<String, dynamic>.from(jsonDecode(e) as Map))
          .toList()
          .reversed
          .take(50)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _items.isEmpty
          ? const Center(child: Text('No alerts yet'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final a = _items[i];
                return ListTile(
                  title: Text(a['title'] as String? ?? 'Alert'),
                  subtitle: Text(a['body'] as String? ?? ''),
                  onTap: () {
                    final route = a['route'] as String?;
                    if (route != null) context.push(route);
                  },
                );
              },
            ),
    );
  }
}

/// Append a device-local alert (max 50).
Future<void> pushLocalAlert({
  required String title,
  required String body,
  String? route,
}) async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getStringList('local_alerts') ?? [];
  raw.add(jsonEncode({
    'title': title,
    'body': body,
    'route': route,
    'at': DateTime.now().toIso8601String(),
  }));
  while (raw.length > 50) {
    raw.removeAt(0);
  }
  await p.setStringList('local_alerts', raw);
}
