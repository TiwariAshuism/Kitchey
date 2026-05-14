import 'package:dio/dio.dart';
import 'package:kitzz/core/api/api_client.dart';

class SubscriptionInfo {
  final String status;
  final String plan;
  final DateTime expiresAt;

  const SubscriptionInfo({
    required this.status,
    required this.plan,
    required this.expiresAt,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      status: json['status'] as String? ?? 'unknown',
      plan: json['plan'] as String? ?? '',
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SubscriptionRepository {
  final ApiClient _apiClient;

  SubscriptionRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<SubscriptionInfo?> getCurrent() async {
    try {
      final response = await _apiClient.dio.get('/api/subscription');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return SubscriptionInfo.fromJson(data);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}
