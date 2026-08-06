import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers an FCM token when Firebase is configured locally.
/// Without google-services / GoogleService-Info, init fails and we stay Realtime-only.
/// Background push: Database Webhook on orders INSERT → Edge Function notify-new-order
/// with secret FCM_SERVICE_ACCOUNT (service-account JSON). No-ops without the secret.
class PushRegistration {
  static Future<void> registerForStall(String stallId) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('PushRegistration: no FCM token for $stallId');
        return;
      }
      final platform = kIsWeb
          ? 'web'
          : Platform.isIOS
              ? 'ios'
              : 'android';
      await upsertToken(stallId: stallId, token: token, platform: platform);
      debugPrint('PushRegistration: token upserted for $stallId');
    } catch (e) {
      debugPrint(
        'PushRegistration: Firebase unavailable — Realtime only ($e)',
      );
    }
  }

  static Future<void> upsertToken({
    required String stallId,
    required String token,
    required String platform,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client.from('device_push_token').upsert({
      'user_id': uid,
      'stall_id': stallId,
      'token': token,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
