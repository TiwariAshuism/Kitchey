import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kitzz/features/messages/data/message_repository.dart';
import 'package:kitzz/features/messages/data/models/message_model.dart';

class MessageDetailScreen extends StatefulWidget {
  final String messageId;

  const MessageDetailScreen({super.key, required this.messageId});

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  MessageModel? _message;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMessage();
  }

  Future<void> _loadMessage() async {
    // In a full implementation, get repository from context
    // For now, show a placeholder
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message?.senderNickname ?? 'Message')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _message == null
          ? const Center(child: Text('Message not found'))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(child: const Icon(Icons.kitchen)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_message!.senderNickname, style: Theme.of(context).textTheme.titleMedium),
                          Text(DateFormat('MMM d, y · h:mm a').format(_message!.createdAt), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Text(_message!.transcript, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
                ],
              ),
            ),
    );
  }
}
