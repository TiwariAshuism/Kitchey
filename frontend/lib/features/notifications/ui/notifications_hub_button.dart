import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kitzz/core/push/app_notifications_cubit.dart';
import 'package:kitzz/core/push/push_notification_models.dart';

/// App bar action: bell + badge; opens tray (presentation only; state from [AppNotificationsCubit]).
class NotificationsHubButton extends StatelessWidget {
  const NotificationsHubButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppNotificationsCubit, AppNotificationsState>(
      builder: (context, state) {
        final count = state.unreadCount;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => _openTray(context),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }

  void _openTray(BuildContext context) {
    final router = GoRouter.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.25,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return BlocBuilder<AppNotificationsCubit, AppNotificationsState>(
              builder: (context, state) {
                return _NotificationsTrayBody(
                  items: state.items,
                  scrollController: scrollController,
                  onMarkAllRead: () {
                    context.read<AppNotificationsCubit>().markAllRead();
                  },
                  onTapItem: (item) {
                    context.read<AppNotificationsCubit>().markRead(item.id);
                    Navigator.of(sheetContext).pop();
                    final mid = item.messageId;
                    if (mid != null && mid.isNotEmpty) {
                      router.push('/messages/$mid');
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _NotificationsTrayBody extends StatelessWidget {
  final List<AppNotificationItem> items;
  final ScrollController scrollController;
  final VoidCallback onMarkAllRead;
  final void Function(AppNotificationItem) onTapItem;

  const _NotificationsTrayBody({
    required this.items,
    required this.scrollController,
    required this.onMarkAllRead,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('No push notifications yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'New kitchen messages appear here when the app is open or when you open the app from a notification.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline, height: 1.35),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Notifications', style: theme.textTheme.titleLarge),
              ),
              TextButton(
                onPressed: onMarkAllRead,
                child: const Text('Mark all read'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return _NotificationTile(item: item, onTap: () => onTapItem(item));
            },
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  String _sourceLabel(AppNotificationSource s) {
    switch (s) {
      case AppNotificationSource.foreground:
        return 'In app';
      case AppNotificationSource.openedFromBackground:
        return 'From background';
      case AppNotificationSource.initialLaunch:
        return 'Cold start';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat('MMM d, h:mm a').format(item.receivedAt.toLocal());
    return ListTile(
      leading: Icon(
        item.read ? Icons.notifications_outlined : Icons.notifications_active_outlined,
        color: item.read ? theme.colorScheme.outline : theme.colorScheme.primary,
      ),
      title: Text(
        item.title,
        style: TextStyle(fontWeight: item.read ? FontWeight.normal : FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.body.isNotEmpty) Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            '$time · ${_sourceLabel(item.source)}',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
