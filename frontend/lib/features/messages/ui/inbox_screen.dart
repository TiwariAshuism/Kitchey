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

  void _showReplySheet(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SendReplySheet(replyRepository: context.read<ReplyRepository>()),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message sent! It will play on Alexa next time.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rasoi'),
        actions: [
          IconButton(icon: const Icon(Icons.devices), onPressed: () => context.push('/devices')),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/settings')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReplySheet(context),
        icon: const Icon(Icons.send),
        label: const Text('Reply to Alexa'),
      ),
      body: BlocBuilder<MessageBloc, MessageState>(
        builder: (context, state) {
          if (state is MessagesLoading || state is MessagesInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MessagesError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => context.read<MessageBloc>().add(MessagesFetchRequested()), child: const Text('Retry')),
                ],
              ),
            );
          }

          if (state is MessagesLoaded) {
            if (state.messages.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No messages yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('Messages from your Alexa will appear here', style: TextStyle(color: Colors.grey)),
                  ],
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
    );
  }
}

class _MessageTile extends StatelessWidget {
  final MessageModel message;

  const _MessageTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: message.isRead ? Colors.grey[300] : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(Icons.kitchen, color: message.isRead ? Colors.grey : Theme.of(context).colorScheme.primary),
      ),
      title: Text(message.senderNickname, style: TextStyle(fontWeight: message.isRead ? FontWeight.normal : FontWeight.bold)),
      subtitle: Text(message.transcript, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(_formatTime(message.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      onTap: () => context.push('/messages/${message.id}'),
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
