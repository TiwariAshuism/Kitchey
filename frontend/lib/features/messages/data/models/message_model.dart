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

  MessageModel copyWith({
    String? id,
    String? senderDeviceId,
    String? recipientUserId,
    String? transcript,
    String? senderNickname,
    DateTime? readAt,
    bool clearReadAt = false,
    DateTime? createdAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      transcript: transcript ?? this.transcript,
      senderNickname: senderNickname ?? this.senderNickname,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

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
