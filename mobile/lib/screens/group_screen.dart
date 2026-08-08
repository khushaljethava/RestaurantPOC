import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../invite_code.dart';
import '../providers/connectivity.dart';
import '../providers/stall.dart';
import '../services/errors.dart';
import '../widgets/ros_ui.dart';

/// Food court membership: join by code, approve/reject neighbours, leave.
/// Every RPC here raises 42501 for non-owners, so the screen is owner-gated —
/// a manager sees the state but no buttons.
class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key});

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  final _code = TextEditingController();
  Map<String, dynamic>? _court;
  List<Map<String, dynamic>> _requests = [];
  Map<String, String> _stallNames = {};
  var _loading = true;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    try {
      final db = Supabase.instance.client;
      final stall = await db
          .from('stall')
          .select('id, name, group_id')
          .eq('id', stallId)
          .single();
      final groupId = stall['group_id'] as String?;

      final court = groupId == null
          ? null
          : await db
                .from('food_court')
                .select('id, name')
                .eq('id', groupId)
                .maybeSingle();

      // RLS scopes this to courts the caller belongs to, so an empty list
      // simply means nothing is pending.
      final requests = groupId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await db
                      .from('group_join_request')
                      .select('id, stall_id, status')
                      .eq('group_id', groupId)
                      .eq('status', 'pending')
                  as List,
            );

      final names = <String, String>{};
      if (requests.isNotEmpty) {
        final rows = await db.from('stall').select('id, name').inFilter('id', [
          for (final r in requests) r['stall_id'] as String,
        ]);
        for (final s in rows as List) {
          names[s['id'] as String] = s['name'] as String;
        }
      }

      if (!mounted) return;
      setState(() {
        _court = court;
        _requests = requests;
        _stallNames = names;
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

  /// Runs [action] then reloads. Returns false if it failed.
  Future<bool> _run(Future<void> Function() action) async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot change membership')),
      );
      return false;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _load();
      if (mounted) setState(() => _busy = false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _error = mapError(e);
        _busy = false;
      });
      return false;
    }
  }

  Future<void> _join() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    final code = normalizeInviteCode(_code.text);
    if (code.isEmpty) {
      setState(() => _error = 'Enter the food court code');
      return;
    }
    final ok = await _run(
      () async => Supabase.instance.client.rpc(
        'request_join_group',
        params: {'p_code': code, 'p_stall_id': stallId},
      ),
    );
    if (ok && mounted) {
      _code.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent — awaiting approval')),
      );
    }
  }

  Future<void> _decide(String requestId, {required bool approve}) => _run(
    () async => Supabase.instance.client.rpc(
      approve ? 'approve_join_request' : 'reject_join_request',
      params: {'p_request_id': requestId},
    ),
  );

  Future<void> _leave() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave food court?'),
        content: const Text(
          'Your stall stops appearing in peer menus and cross-stall '
          'settlement. Past orders and bills are unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () async => Supabase.instance.client.rpc(
        'leave_group',
        params: {'p_stall_id': stallId},
      ),
    );
  }

  Future<void> _shareCode() async {
    final groupId = _court?['id'] as String?;
    if (groupId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await Supabase.instance.client.rpc(
        'create_group_invite',
        params: {'p_group_id': groupId},
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Food court code'),
          content: SelectableText(
            '$code',
            style: Theme.of(ctx).textTheme.headlineSmall,
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: '$code'));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
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
    final isOwner = ref.watch(activeRoleProvider) == 'owner';
    final court = _court;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food court'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const RosLoading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!isOwner)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('View only — only an owner can change this.'),
                  ),
                RosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        court == null ? 'Not in a food court' : 'Member of',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (court != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          court['name'] as String,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (court == null && isOwner) ...[
                  RosSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Join a food court',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ask a member stall for their code. They approve the '
                          'request before menus are shared.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Food court code',
                            hintText: 'ABCD-1234',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy ? null : _join,
                          child: const Text('Request to join'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (court != null) ...[
                  Text(
                    'Pending requests',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_requests.isEmpty)
                    const RosSurfaceCard(child: Text('Nothing pending'))
                  else
                    for (final r in _requests)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RosSurfaceCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _stallNames[r['stall_id']] ?? 'A stall',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              if (isOwner) ...[
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _decide(
                                          r['id'] as String,
                                          approve: false,
                                        ),
                                  child: const Text('Reject'),
                                ),
                                FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _decide(
                                          r['id'] as String,
                                          approve: true,
                                        ),
                                  child: const Text('Approve'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  if (isOwner) ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _shareCode,
                      icon: const Icon(Icons.share),
                      label: const Text('Create invite code'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : _leave,
                      child: const Text('Leave food court'),
                    ),
                  ],
                ],

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  RosErrorText(_error!),
                ],
              ],
            ),
    );
  }
}
