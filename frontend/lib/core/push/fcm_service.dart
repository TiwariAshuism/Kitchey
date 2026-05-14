import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitzz/features/auth/data/auth_repository.dart';

/// Wires Firebase Cloud Messaging to the backend and in-app navigation.
class FcmService {
  FcmService({
    required AuthRepository authRepository,
    GoRouter? router,
    GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey,
    void Function()? onInboxShouldRefresh,
  })  : _authRepository = authRepository,
        _router = router,
        _scaffoldMessengerKey = scaffoldMessengerKey,
        _onInboxShouldRefresh = onInboxShouldRefresh;

  final AuthRepository _authRepository;
  final void Function()? _onInboxShouldRefresh;
  GoRouter? _router;
  final GlobalKey<ScaffoldMessengerState>? _scaffoldMessengerKey;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  void attachRouter(GoRouter router) {
    _router = router;
  }

  /// Requests notification permission, listens for messages, and opens deep links.
  Future<void> configureMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      if (kDebugMode) {
        debugPrint('FCM permission: ${settings.authorizationStatus}');
      }

      _subscriptions.add(
        FirebaseMessaging.onMessage.listen(_onForegroundMessage),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(
          _handleNotificationNavigation,
        ),
      );

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationNavigation(initial);
        });
      }

      _subscriptions.add(
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
          await _pushTokenIfLoggedIn(token);
        }),
      );
    } catch (e, st) {
      debugPrint('FCM configureMessaging failed: $e\n$st');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (message.data.containsKey('message_id')) {
      _onInboxShouldRefresh?.call();
    }
    final title = message.notification?.title ?? 'Rasoi';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final messenger = _scaffoldMessengerKey?.currentState;
    if (messenger != null && body.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('$title: $body')),
      );
    } else if (kDebugMode) {
      debugPrint('FCM foreground: $title — $body');
    }
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    final id = message.data['message_id'] ?? message.data['messageId'];
    if (id == null || id.isEmpty) {
      return;
    }
    final router = _router;
    if (router == null) {
      return;
    }
    router.go('/messages/$id');
  }

  /// Sends the current FCM token to the API when a session exists.
  Future<void> syncTokenIfLoggedIn() async {
    final loggedIn = await _authRepository.isLoggedIn();
    if (!loggedIn) {
      return;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      return;
    }
    await _pushTokenIfLoggedIn(token);
  }

  Future<void> _pushTokenIfLoggedIn(String token) async {
    final loggedIn = await _authRepository.isLoggedIn();
    if (!loggedIn) {
      return;
    }
    try {
      await _authRepository.updateFcmToken(token);
    } catch (e, st) {
      debugPrint('FCM token sync failed: $e\n$st');
    }
  }

  /// Clears the device token locally when the user signs out.
  Future<void> clearDevicePushRegistration() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e, st) {
      debugPrint('FCM deleteToken failed: $e\n$st');
    }
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }
}
