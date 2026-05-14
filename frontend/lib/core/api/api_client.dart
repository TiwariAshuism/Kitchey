import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Resolves API base URL from `--dart-define=API_BASE_URL=...`.
///
/// In **debug** builds only, if `API_BASE_URL` is empty, falls back to
/// `API_BASE_URL_DEBUG` (default `http://127.0.0.1:8080`) so local dev works
/// without passing defines every time.
///
/// **Release/profile** builds require an explicit `API_BASE_URL` or startup
/// will throw [StateError].
String resolveApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) {
    return fromEnv;
  }
  if (kDebugMode) {
    const debugFallback = String.fromEnvironment(
      'API_BASE_URL_DEBUG',
      defaultValue: 'https://gratify-handrail-fade.ngrok-free.dev',
    );
    return debugFallback;
  }
  throw StateError(
    'Missing API_BASE_URL. Release builds require '
    '--dart-define=API_BASE_URL=https://your-api-host',
  );
}

class ApiClient {
  final Dio dio;
  final FlutterSecureStorage _storage;

  ApiClient({required FlutterSecureStorage storage})
    : _storage = storage,
      dio = Dio(
        BaseOptions(
          baseUrl: resolveApiBaseUrl(),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    final base = dio.options.baseUrl;
    if (base.contains('ngrok')) {
      dio.options.headers['ngrok-skip-browser-warning'] = 'true';
    }
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

        err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryResponse = await _dio.fetch(err.requestOptions);
        handler.resolve(retryResponse);
      } catch (e) {
        await _storage.delete(key: 'access_token');
        await _storage.delete(key: 'refresh_token');
        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }
}
