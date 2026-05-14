import 'package:kitzz/core/api/api_client.dart';

class ReplyModel {
  final String id;
  final String targetDeviceId;
  final String textContent;
  final String? senderName;
  final DateTime? deliveredAt;
  final DateTime createdAt;

  ReplyModel({required this.id, required this.targetDeviceId, required this.textContent, this.senderName, this.deliveredAt, required this.createdAt});

  bool get isDelivered => deliveredAt != null;

  factory ReplyModel.fromJson(Map<String, dynamic> json) {
    return ReplyModel(
      id: json['id'],
      targetDeviceId: json['target_device_id'],
      textContent: json['text_content'],
      senderName: json['sender_name'],
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ReplyRepository {
  final ApiClient _apiClient;

  ReplyRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Send a reply to all paired devices (plays on Alexa next time)
  Future<void> sendReply(String text, {String? deviceId}) async {
    await _apiClient.dio.post('/api/replies', data: {'text': text, if (deviceId != null) 'device_id': deviceId});
  }

  /// Get list of sent replies
  Future<List<ReplyModel>> getSentReplies() async {
    final response = await _apiClient.dio.get('/api/replies');
    final replies = (response.data['replies'] as List? ?? []).map((json) => ReplyModel.fromJson(json)).toList();
    return replies;
  }
}
