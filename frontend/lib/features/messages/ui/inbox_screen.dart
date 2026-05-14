import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kitzz/features/messages/bloc/message_bloc.dart';
import 'package:kitzz/features/messages/bloc/message_event.dart';
import 'package:kitzz/features/messages/bloc/message_state.dart';
import 'package:kitzz/features/messages/data/models/message_model.dart';
import 'package:kitzz/features/replies/data/reply_repository.dart';
import 'package:kitzz/features/replies/ui/send_reply_sheet.dart';
import 'package:kitzz/features/notifications/ui/notifications_hub_button.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MessageBloc>().add(MessagesFetchRequested());
    });
  }

  Future<void> _showReplySheet(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SendReplySheet(replyRepository: context.read<ReplyRepository>()),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent! It will play on Alexa next time.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BlocListener<MessageBloc, MessageState>(
      listenWhen: (prev, curr) {
        if (curr is! MessagesLoaded || curr.paginationError == null) {
          return false;
        }
        if (prev is MessagesLoaded && prev.paginationError == curr.paginationError) {
          return false;
        }
        return true;
      },
      listener: (context, state) {
        final s = state as MessagesLoaded;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.paginationError!)));
        context.read<MessageBloc>().add(MessagePaginationErrorConsumed());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rasoi'),
          actions: [
            const NotificationsHubButton(),
            Tooltip(
              message: 'Paired devices',
              child: IconButton(
                icon: const Icon(Icons.devices_outlined),
                onPressed: () => context.push('/devices'),
              ),
            ),
            Tooltip(
              message: 'Settings',
              child: IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings'),
              ),
            ),
          ],
        ),
        floatingActionButton: Semantics(
          label: 'Reply to Alexa',
          button: true,
          child: FloatingActionButton.extended(
            onPressed: () => _showReplySheet(context),
            icon: const Icon(Icons.send),
            label: const Text('Reply to Alexa'),
          ),
        ),
        body: BlocBuilder<MessageBloc, MessageState>(
          builder: (context, state) {
            if (state is MessagesLoading || state is MessagesInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is MessagesError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_outlined, size: 56, color: colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.outline),
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        label: 'Retry loading messages',
                        child: FilledButton.icon(
                          onPressed: () => context.read<MessageBloc>().add(MessagesFetchRequested()),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is MessagesLoaded) {
              if (state.messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.speaker_notes_outlined, size: 72, color: colorScheme.outline),
                        const SizedBox(height: 20),
                        Text(
                          'No messages yet',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'When someone uses Rasoi on your kitchen Alexa, the transcript appears here instantly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.outline, height: 1.4),
                        ),
                        const SizedBox(height: 28),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/devices'),
                          icon: const Icon(Icons.devices_other_outlined),
                          label: const Text('Pair an Echo'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<MessageBloc>().add(MessageRefreshRequested());
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                      context.read<MessageBloc>().add(MessagesLoadMore());
                    }
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      return _MessageTile(message: state.messages[index]);
                    },
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final MessageModel message;

  const _MessageTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Message from ${message.senderNickname}, ${message.isRead ? 'read' : 'unread'}',
      button: true,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: message.isRead ? scheme.surfaceContainerHighest : scheme.primaryContainer,
          child: Icon(
            Icons.kitchen_outlined,
            color: message.isRead ? scheme.outline : scheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          message.senderNickname,
          style: TextStyle(fontWeight: message.isRead ? FontWeight.normal : FontWeight.w600),
        ),
        subtitle: Text(message.transcript, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(
          _formatTime(message.createdAt),
          style: TextStyle(fontSize: 12, color: scheme.outline),
        ),
        onTap: () => context.push('/messages/${message.id}'),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(dateTime);
  }
}
