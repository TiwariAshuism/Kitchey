import 'package:kitzz/core/api/api_client.dart';
import 'package:kitzz/features/messages/data/models/message_model.dart';

class MessageRepository {
  final ApiClient _apiClient;

  MessageRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<MessageModel>> getMessages({String? cursor, int limit = 20}) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _apiClient.dio.get('/api/messages', queryParameters: params);
    final messages = (response.data['messages'] as List? ?? []).map((json) => MessageModel.fromJson(json)).toList();
    return messages;
  }

  Future<MessageModel> getMessage(String id) async {
    final response = await _apiClient.dio.get('/api/messages/$id');
    return MessageModel.fromJson(response.data);
  }

  Future<void> markAsRead(String id) async {
    await _apiClient.dio.put('/api/messages/$id/read');
  }

  Future<void> deleteMessage(String id) async {
    await _apiClient.dio.delete('/api/messages/$id');
  }
}
