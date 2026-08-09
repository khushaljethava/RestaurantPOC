import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/errors.dart';

/// Returns the approver user id when PIN verifies, else null.
Future<String?> showManagerPinSheet(
  BuildContext context, {
  required String stallId,
  required String title,
  String? hintUserId,
}) async {
  final pinCtrl = TextEditingController();
  String? error;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Enter manager / owner 4-digit PIN'),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'PIN'),
                ),
                if (error != null)
                  Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () async {
                    final pin = pinCtrl.text.trim();
                    if (pin.length != 4) {
                      setLocal(() => error = 'Enter 4 digits');
                      return;
                    }
                    // Try hint user first, else current user (owner/manager on device).
                    final candidates = <String>{
                      if (hintUserId != null) hintUserId,
                      if (Supabase.instance.client.auth.currentUser?.id != null)
                        Supabase.instance.client.auth.currentUser!.id,
                    };
                    try {
                      // List managers/owners for stall and try each — shared device.
                      final rows = await Supabase.instance.client
                          .from('staff_membership')
                          .select('user_id')
                          .eq('stall_id', stallId)
                          .inFilter('role', ['owner', 'manager']);
                      for (final r in rows as List) {
                        candidates.add(r['user_id'] as String);
                      }
                      for (final uid in candidates) {
                        final ok = await Supabase.instance.client.rpc(
                          'verify_staff_pin',
                          params: {
                            'p_stall_id': stallId,
                            'p_user_id': uid,
                            'p_pin': pin,
                          },
                        );
                        if (ok == true) {
                          if (ctx.mounted) Navigator.pop(ctx, uid);
                          return;
                        }
                      }
                      setLocal(() => error = 'Wrong PIN');
                    } catch (e) {
                      setLocal(() => error = mapError(e));
                    }
                  },
                  child: const Text('Approve'),
                ),
              ],
            ),
          );
        },
      );
    },
  ).whenComplete(pinCtrl.dispose);
}
