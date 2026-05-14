import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kitzz/features/messages/bloc/message_bloc.dart';
import 'package:kitzz/features/messages/bloc/message_event.dart';
import 'package:kitzz/features/messages/data/message_repository.dart';
import 'package:kitzz/features/messages/data/models/message_model.dart';
import 'package:kitzz/core/tts/message_tts_controller.dart';

class MessageDetailScreen extends StatefulWidget {
  final String messageId;

  const MessageDetailScreen({super.key, required this.messageId});

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  MessageModel? _message;
  bool _loading = true;
  String? _error;
  late final MessageTtsController _tts;

  @override
  void initState() {
    super.initState();
    _tts = MessageTtsController();
    _tts.addListener(_onTtsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMessage();
      }
    });
  }

  void _onTtsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(MessageDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId) {
      unawaited(_tts.stop());
      _message = null;
      _error = null;
      _loading = true;
      _loadMessage();
    }
  }

  @override
  void dispose() {
    _tts.removeListener(_onTtsChanged);
    _tts.dispose();
    super.dispose();
  }

  Future<void> _loadMessage() async {
    final repo = context.read<MessageRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var msg = await repo.getMessage(widget.messageId);
      if (!mounted) return;
      if (!msg.isRead) {
        try {
          await repo.markAsRead(widget.messageId);
          msg = msg.copyWith(readAt: DateTime.now().toUtc());
        } catch (_) {
          // Message still shown if mark-read fails
        }
        if (mounted) {
          context.read<MessageBloc>().add(MessageRefreshRequested());
        }
      }
      if (!mounted) return;
      setState(() {
        _message = msg;
        _loading = false;
        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      String msg = 'Failed to load message';
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        msg = data['error'].toString();
      } else if (e.response?.statusCode == 404) {
        msg = 'Message not found';
      }
      setState(() {
        _loading = false;
        _error = msg;
        _message = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load message';
        _message = null;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This removes the message from your inbox.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<MessageRepository>().deleteMessage(widget.messageId);
      if (!mounted) return;
      context.read<MessageBloc>().add(MessageRefreshRequested());
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      String msg = 'Could not delete message';
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        msg = data['error'].toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete message')));
    }
  }

  Future<void> _toggleListen() async {
    final text = _message?.transcript;
    if (text == null || text.isEmpty) return;
    if (_tts.isSpeaking) {
      await _tts.stop();
    } else {
      await _tts.speak(text);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_message?.senderNickname ?? 'Message'),
        actions: [
          if (_message != null && !_loading && _error == null) ...[
            Tooltip(
              message: _tts.isSpeaking ? 'Stop reading' : 'Read aloud',
              child: IconButton(
                icon: Icon(_tts.isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                onPressed: _toggleListen,
              ),
            ),
            Tooltip(
              message: 'Delete message',
              child: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _confirmDelete,
              ),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    Semantics(
                      label: 'Retry loading message',
                      child: ElevatedButton(
                        onPressed: _loadMessage,
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _message == null
          ? const Center(child: Text('Message not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(Icons.kitchen, color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _message!.senderNickname,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              DateFormat('MMM d, y · h:mm a').format(_message!.createdAt),
                              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  SelectableText(
                    _message!.transcript,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
    );
  }
}
