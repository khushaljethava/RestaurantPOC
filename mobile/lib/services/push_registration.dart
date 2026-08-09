import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/notifications_screen.dart';
import 'telemetry.dart';

/// Registers an FCM token when Firebase is configured locally.
///
/// Callers: app.dart bindRouter (~206); home_screen.dart prime/register/delete
/// (~26–27, ~43, ~144). Replaces the prior same-path stub that lacked Android
/// channels. Prefs inbox via pushLocalAlert: title/body/route/at ISO-8601.
class PushRegistration {
  static GoRouter? _router;
  static bool _handlersBound = false;
  static final _local = FlutterLocalNotificationsPlugin();

  /// Must match Edge Function / FCM payload `android.notification.channel_id`.
  static const newOrderChannelId = 'new_order';

  static const _newOrderChannel = AndroidNotificationChannel(
    newOrderChannelId,
    'New orders',
    description: 'High-priority alerts when a new stall order arrives',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> bindRouter(GoRouter router) async {
    _router = router;
    await ensureHandlers();
  }

  static Future<void> _initLocalNotifications() async {
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(
      settings: init,
      onDidReceiveNotificationResponse: (resp) {
        final router = _router;
        if (router == null) return;
        // Dine-in only — open stall board for any local notification tap.
        router.go('/stall');
      },
    );
    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_newOrderChannel);
    }
  }

  static Future<void> ensureHandlers() async {
    if (_handlersBound) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await _initLocalNotifications();
      if (Platform.isAndroid) {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _openFromMessage(initial);
      _handlersBound = true;
    } catch (e) {
      debugPrint('PushRegistration handlers: $e');
    }
  }

  static Future<void> _onForeground(RemoteMessage msg) async {
    final title =
        msg.notification?.title ?? msg.data['title'] ?? 'New order';
    final body = msg.notification?.body ??
        msg.data['body'] ??
        'Tap to open the stall board';
    final type = msg.data['type'] ?? msg.data['route'] ?? 'new_order';
    const route = '/stall';

    Telemetry.event('push_foreground', {
      'type': type,
      'stall_id': msg.data['stall_id'],
    });

    await pushLocalAlert(title: title, body: body, route: route);

    await _local.show(
      id: msg.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          newOrderChannelId,
          'New orders',
          channelDescription: _newOrderChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: route,
    );
  }

  static void _openFromMessage(RemoteMessage msg) {
    final type = msg.data['type'] ?? msg.data['route'];
    final router = _router;
    if (router == null) return;
    router.go('/stall');
    Telemetry.event('push_open', {'type': type});
  }

  static Future<bool> primePermission(BuildContext context) async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      await ensureHandlers();
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        return true;
      }
      if (!context.mounted) return false;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable order alerts'),
          content: const Text(
            'Allow notifications so new stall orders reach this device even when the app is in the background.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (go != true) return false;
      final r = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return r.authorizationStatus == AuthorizationStatus.authorized ||
          r.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  static Future<void> registerForStall(String stallId) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await ensureHandlers();
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
      debugPrint('PushRegistration: token register failed — Realtime only ($e)');
    }
  }

  static Future<void> deleteForLogout() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      await Supabase.instance.client
          .from('device_push_token')
          .delete()
          .eq('user_id', uid);
      if (Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (e) {
      debugPrint('PushRegistration delete: $e');
    }
  }

  static Future<void> upsertToken({
    required String stallId,
    required String token,
    required String platform,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client.from('device_push_token').upsert(
      {
        'user_id': uid,
        'stall_id': stallId,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,stall_id,token',
    );
  }
}
