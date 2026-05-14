import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kitzz/core/push/push_notification_models.dart';

class AppNotificationsState extends Equatable {
  final List<AppNotificationItem> items;

  const AppNotificationsState({this.items = const []});

  int get unreadCount => items.where((e) => !e.read).length;

  AppNotificationsState copyWith({List<AppNotificationItem>? items}) {
    return AppNotificationsState(items: items ?? this.items);
  }

  @override
  List<Object?> get props => [items];
}

/// Holds recent FCM notifications for the in-app tray (foreground + opened-from-tray).
class AppNotificationsCubit extends Cubit<AppNotificationsState> {
  AppNotificationsCubit() : super(const AppNotificationsState());

  static const int _maxItems = 50;

  void ingest(RemoteMessage message, {required AppNotificationSource source}) {
    final incoming = AppNotificationItem.fromRemoteMessage(message, source: source);
    final list = List<AppNotificationItem>.from(state.items);
    if (incoming.messageId != null) {
      list.removeWhere((e) => e.messageId == incoming.messageId);
    }
    list.insert(0, incoming);
    if (list.length > _maxItems) {
      list.removeRange(_maxItems, list.length);
    }
    emit(AppNotificationsState(items: list));
  }

  void markRead(String id) {
    final next = state.items.map((e) => e.id == id ? e.copyWith(read: true) : e).toList();
    emit(state.copyWith(items: next));
  }

  void markReadByMessageId(String? messageId) {
    if (messageId == null || messageId.isEmpty) return;
    markRead('msg_$messageId');
  }

  void markAllRead() {
    final next = state.items.map((e) => e.copyWith(read: true)).toList();
    emit(state.copyWith(items: next));
  }

  void clear() {
    emit(const AppNotificationsState());
  }
}
