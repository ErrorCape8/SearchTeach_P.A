import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'notification_platform.dart';

const _notificationTokenKey = 'notification_device_token';
const _notificationStorage = FlutterSecureStorage();

const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_APP_ID');
const _messagingSenderId =
    String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
const _vapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

StreamSubscription<RemoteMessage>? _foregroundMessages;
StreamSubscription<String>? _refreshedTokens;

bool get isPushConfigured =>
    defaultTargetPlatform == TargetPlatform.android ||
    (kIsWeb &&
        _apiKey.isNotEmpty &&
        _appId.isNotEmpty &&
        _messagingSenderId.isNotEmpty &&
        _projectId.isNotEmpty &&
        _vapidKey.isNotEmpty);

Future<String?> enableDeviceNotifications(Dio dio) async {
  if (!isPushConfigured) return null;
  if (Firebase.apps.isEmpty) {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
          authDomain: _authDomain.isEmpty ? null : _authDomain,
          storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  }
  final messaging = FirebaseMessaging.instance;
  final permission = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  if (permission.authorizationStatus != AuthorizationStatus.authorized &&
      permission.authorizationStatus != AuthorizationStatus.provisional) {
    return '';
  }
  final token = await messaging.getToken(vapidKey: kIsWeb ? _vapidKey : null);
  if (token == null || token.isEmpty) return '';
  await registerNotificationDevice(dio, token);
  _foregroundMessages ??= FirebaseMessaging.onMessage.listen((message) {
    showDeviceNotification(
      message.notification?.title ?? 'SearchTeach',
      message.notification?.body ?? 'Tienes un aviso nuevo.',
    );
  });
  _refreshedTokens ??= messaging.onTokenRefresh.listen(
    (newToken) => registerNotificationDevice(dio, newToken),
  );
  return token;
}

Future<void> registerNotificationDevice(Dio dio, String token) async {
  await dio.post<void>('/api/notificaciones/dispositivos', data: {
    'token': token,
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
  });
  await _notificationStorage.write(key: _notificationTokenKey, value: token);
}

Future<bool> isDeviceNotificationsEnabled() async =>
    (await _notificationStorage.read(key: _notificationTokenKey))?.isNotEmpty ==
    true;

Future<void> disableDeviceNotifications(Dio dio) async {
  final registeredToken =
      await _notificationStorage.read(key: _notificationTokenKey);
  String? currentToken;
  if (Firebase.apps.isNotEmpty) {
    final messaging = FirebaseMessaging.instance;
    currentToken =
        await messaging.getToken(vapidKey: kIsWeb ? _vapidKey : null);
  }

  final tokens = {registeredToken, currentToken}
    ..removeWhere((token) => token == null || token.isEmpty);
  for (final token in tokens) {
    await dio.delete<void>(
      '/api/notificaciones/dispositivos',
      queryParameters: {'token': token},
    );
  }
  await _notificationStorage.delete(key: _notificationTokenKey);

  if (Firebase.apps.isEmpty) return;
  final messaging = FirebaseMessaging.instance;
  await _foregroundMessages?.cancel();
  await _refreshedTokens?.cancel();
  _foregroundMessages = null;
  _refreshedTokens = null;
  await messaging.deleteToken();
}
