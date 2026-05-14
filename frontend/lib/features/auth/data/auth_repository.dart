import 'package:kitzz/core/api/api_client.dart';
import 'package:kitzz/features/auth/data/models/auth_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  AuthRepository({required ApiClient apiClient, required FlutterSecureStorage storage}) : _apiClient = apiClient, _storage = storage;

  Future<AuthResponse> register(String name, String email, String password) async {
    final response = await _apiClient.dio.post('/api/auth/register', data: {'name': name, 'email': email, 'password': password});
    final authResponse = AuthResponse.fromJson(response.data);
    await _saveTokens(authResponse.tokens);
    return authResponse;
  }

  Future<AuthResponse> login(String email, String password) async {
    final response = await _apiClient.dio.post('/api/auth/login', data: {'email': email, 'password': password});
    final authResponse = AuthResponse.fromJson(response.data);
    await _saveTokens(authResponse.tokens);
    return authResponse;
  }

  Future<void> updateFcmToken(String token) async {
    await _apiClient.dio.put('/api/auth/fcm-token', data: {'token': token});
  }

  Future<void> deleteAccount() async {
    await _apiClient.dio.delete('/api/auth/account');
    await logout();
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_id');
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  Future<void> _saveTokens(TokenPair tokens) async {
    await _storage.write(key: 'access_token', value: tokens.accessToken);
    await _storage.write(key: 'refresh_token', value: tokens.refreshToken);
  }
}
