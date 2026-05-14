import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kitzz/features/replies/data/reply_repository.dart';

/// A bottom sheet for composing and sending a reply to Alexa
class SendReplySheet extends StatefulWidget {
  final ReplyRepository replyRepository;
  final String? deviceId; // If null, sends to all devices

  const SendReplySheet({super.key, required this.replyRepository, this.deviceId});

  @override
  State<SendReplySheet> createState() => _SendReplySheetState();
}

class _SendReplySheetState extends State<SendReplySheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (text.length > 500) {
      setState(() => _error = 'Message too long (max 500 characters)');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await widget.replyRepository.sendReply(text, deviceId: widget.deviceId);
      if (mounted) {
        Navigator.of(context).pop(true); // return success
      }
    } on DioException catch (e) {
      String msg = 'Failed to send. Please try again.';
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        msg = data['error'].toString();
      } else if (e.response?.statusCode == 404) {
        msg = 'No paired Echo yet. Open Devices and tap Pair Echo first.';
      }
      setState(() {
        _sending = false;
        _error = msg;
      });
    } catch (e) {
      setState(() {
        _sending = false;
        _error = 'Failed to send. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send to Alexa', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('This message will play on your Alexa device next time someone opens Rasoi.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Type your message (e.g. "Thank you!" or "Dinner is ready")',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              label: Text(_sending ? 'Sending...' : 'Send to Alexa'),
            ),
          ),
        ],
      ),
    );
  }
}
