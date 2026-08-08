import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/errors.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key, required this.billId});
  final String billId;

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<Map<String, dynamic>> _rows = [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('audit_log')
          .select('action, reason, created_at, actor_id, payload')
          .eq('entity_id', widget.billId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = mapError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (context, i) {
                    final r = _rows[i];
                    return ListTile(
                      title: Text(r['action'] as String? ?? ''),
                      subtitle: Text(
                        '${r['reason'] ?? ''}\n${r['created_at'] ?? ''}',
                      ),
                    );
                  },
                ),
    );
  }
}
