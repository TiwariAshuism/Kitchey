import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  // Same host the Alexa skill uses (BACKEND_URL). Override per build:
  //   flutter run --dart-define=API_BASE_URL=https://YOUR.ngrok-free.app
  // Android emulator -> host machine: --dart-define=API_BASE_URL=http://10.0.2.2:8080
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://gratify-handrail-fade.ngrok-free.dev',
  );

  final Dio dio;
  final FlutterSecureStorage _storage;

  ApiClient({required FlutterSecureStorage storage})
    : _storage = storage,
      dio = Dio(
        BaseOptions(
          baseUrl: _defaultBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            // Bypass ngrok's browser-warning interstitial on free plan.
            'ngrok-skip-browser-warning': 'true',
          },
        ),
      ) {
    dio.interceptors.add(_AuthInterceptor(storage: _storage, dio: dio));
  }
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  _AuthInterceptor({required FlutterSecureStorage storage, required Dio dio})
    : _storage = storage,
      _dio = dio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        handler.next(err);
        return;
      }

      try {
        final response = await _dio.post(
          '/api/auth/refresh',
          data: {'refresh_token': refreshToken},
          options: Options(headers: {'Authorization': ''}),
        );

        final newAccessToken = response.data['access_token'] as String;
        final newRefreshToken = response.data['refresh_token'] as String;

        await _storage.write(key: 'access_token', value: newAccessToken);
        await _storage.write(key: 'refresh_token', value: newRefreshToken);

        // Retry original request
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryResponse = await _dio.fetch(err.requestOptions);
        handler.resolve(retryResponse);
      } catch (e) {
        // Refresh failed, clear tokens
        await _storage.delete(key: 'access_token');
        await _storage.delete(key: 'refresh_token');
        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }
}
