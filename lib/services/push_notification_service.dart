import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/firebase_messaging_config.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _attemptedUserId;
  String? _registeredUserId;

  Future<String?> registerCurrentDevice(SupabaseClient supabase) async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      return 'Firebase Messaging không được hỗ trợ trên nền tảng desktop này.';
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified || user.email == null) {
      return 'Cần tài khoản Google có email đã xác thực để bật thông báo.';
    }
    if (_attemptedUserId == user.uid) return null;
    if (kIsWeb && FirebaseMessagingConfig.webVapidKey.isEmpty) {
      _attemptedUserId = user.uid;
      return 'Để bật thông báo trên Web, hãy cấu hình FCM_WEB_VAPID_KEY.';
    }

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      _attemptedUserId = user.uid;
      return 'Bạn chưa cấp quyền nhận thông báo trên thiết bị này.';
    }

    final token = await messaging.getToken(
      vapidKey: kIsWeb ? FirebaseMessagingConfig.webVapidKey : null,
    );
    if (token == null || token.isEmpty) {
      _attemptedUserId = user.uid;
      return 'Firebase Messaging chưa cấp token cho thiết bị này.';
    }

    await _saveToken(supabase, token);
    _attemptedUserId = user.uid;
    _registeredUserId = user.uid;
    _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen(
      (refreshedToken) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          unawaited(
            _saveToken(supabase, refreshedToken).catchError((error) {
              debugPrint('FCM token refresh registration failed: $error');
            }),
          );
        }
      },
      onError: (Object error) {
        debugPrint('FCM token refresh stream failed: $error');
      },
    );
    return null;
  }

  Future<void> unregisterCurrentDevice(SupabaseClient supabase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _registeredUserId != user.uid) return;
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? FirebaseMessagingConfig.webVapidKey : null,
    );
    if (token == null || token.isEmpty) return;
    await supabase.rpc('unregister_device_token', params: {'p_token': token});
    _attemptedUserId = null;
    _registeredUserId = null;
  }

  Future<void> _saveToken(SupabaseClient supabase, String token) async {
    await supabase.rpc(
      'register_device_token',
      params: {'p_token': token, 'p_platform': _platformName},
    );
  }

  String get _platformName => kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          TargetPlatform.macOS => 'macos',
          TargetPlatform.windows => 'windows',
          TargetPlatform.linux => 'linux',
          TargetPlatform.fuchsia => 'android',
        };
}
