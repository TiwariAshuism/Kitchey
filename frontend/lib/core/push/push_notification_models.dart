import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Where the push was surfaced in the app lifecycle.
enum AppNotificationSource {
  foreground,
  openedFromBackground,
  initialLaunch,
}

/// One row in the in-app notification tray (FCM-driven; not persisted).
class AppNotificationItem extends Equatable {
  final String id;
  final String title;
  final String body;
  final String? messageId;
  final DateTime receivedAt;
  final AppNotificationSource source;
  final bool read;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.messageId,
    required this.receivedAt,
    required this.source,
    this.read = false,
  });

  static String? _messageIdFrom(RemoteMessage message) {
    final raw = message.data['message_id'] ?? message.data['messageId'];
    if (raw == null) return null;
    final s = raw.toString();
    return s.isEmpty ? null : s;
  }

  factory AppNotificationItem.fromRemoteMessage(
    RemoteMessage message, {
    required AppNotificationSource source,
  }) {
    final title = message.notification?.title ?? 'Rasoi';
    final body = message.notification?.body ?? message.data['body']?.toString() ?? '';
    final mid = _messageIdFrom(message);
    final id = mid != null ? 'msg_$mid' : 't_${DateTime.now().microsecondsSinceEpoch}';
    return AppNotificationItem(
      id: id,
      title: title,
      body: body.isEmpty ? '(No preview)' : body,
      messageId: mid,
      receivedAt: DateTime.now().toUtc(),
      source: source,
    );
  }

  AppNotificationItem copyWith({bool? read}) {
    return AppNotificationItem(
      id: id,
      title: title,
      body: body,
      messageId: messageId,
      receivedAt: receivedAt,
      source: source,
      read: read ?? this.read,
    );
  }

  @override
  List<Object?> get props => [id, title, body, messageId, receivedAt, source, read];
}
