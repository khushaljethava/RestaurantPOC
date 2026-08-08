import 'package:supabase_flutter/supabase_flutter.dart';

/// Single channel manager for stall-scoped realtime.
class RealtimeChannelManager {
  RealtimeChannelManager(this._client);

  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, DateTime> lastEventAt = {};
  final Map<String, void Function()> _refetch = {};

  void watchStallOrders({
    required String stallId,
    required void Function() onChange,
  }) {
    final key = 'stall:$stallId:orders';
    _refetch[key] = onChange;
    if (_channels.containsKey(key)) return;
    final ch = _client
        .channel(key)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'stall_id',
            value: stallId,
          ),
          callback: (_) {
            lastEventAt[key] = DateTime.now();
            onChange();
          },
        )
        .subscribe();
    _channels[key] = ch;
  }

  void resubscribeAll() {
    for (final e in _refetch.entries) {
      e.value();
    }
  }

  String connectionLabel(String key) {
    final t = lastEventAt[key];
    if (t == null) return 'Connecting…';
    final age = DateTime.now().difference(t);
    if (age.inSeconds < 30) return 'Live';
    if (age.inSeconds < 90) return 'Reconnecting…';
    return 'Stale — pull to refresh';
  }

  Future<void> dispose() async {
    for (final ch in _channels.values) {
      await _client.removeChannel(ch);
    }
    _channels.clear();
  }
}

final realtimeManager = RealtimeChannelManager(Supabase.instance.client);
