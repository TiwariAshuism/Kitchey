class MessageModel {
  final String id;
  final String senderDeviceId;
  final String recipientUserId;
  final String transcript;
  final String senderNickname;
  final DateTime? readAt;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.senderDeviceId,
    required this.recipientUserId,
    required this.transcript,
    required this.senderNickname,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      senderDeviceId: json['sender_device_id'],
      recipientUserId: json['recipient_user_id'],
      transcript: json['transcript'],
      senderNickname: json['sender_nickname'] ?? 'Unknown',
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
