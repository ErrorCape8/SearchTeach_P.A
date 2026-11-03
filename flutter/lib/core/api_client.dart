import 'dart:async';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_error.dart';

/// Android emulator: 10.0.2.2 = tu PC. iOS simulator / web: localhost.
/// Celular físico: usa la IP de tu PC (ej. http://192.168.1.20:8081).
const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

String get baseUrl {
  if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
  if (kIsWeb) return 'http://localhost:8081';
  return Platform.isAndroid ? 'http://10.0.2.2:8081' : 'http://localhost:8081';
}

const _tokenKey = 'token';

final _authExpiredController = StreamController<void>.broadcast(sync: true);
Stream<void> get authExpiredEvents => _authExpiredController.stream;
final _appErrorController =
    StreamController<AppErrorInfo>.broadcast(sync: true);
Stream<AppErrorInfo> get appErrorEvents => _appErrorController.stream;

// ignore: unused_element
final secureStorageProvider = Provider((_) => const FlutterSecureStorage());

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  var redirectingAfterExpiredToken = false;
  var showingGlobalError = false;

  // Agrega el JWT a las llamadas protegidas y cierra la sesión si el servidor
  // informa que el token venció o dejó de ser válido.
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      if (!options.path.startsWith('/api/auth')) {
        final token = await storage.read(key: _tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onResponse: (response, handler) {
      showingGlobalError = false;
      if (response.requestOptions.path.startsWith('/api/auth') &&
          (response.statusCode ?? 500) < 400) {
        redirectingAfterExpiredToken = false;
      }
      handler.next(response);
    },
    onError: (error, handler) async {
      final isAuthRequest = error.requestOptions.path.startsWith('/api/auth');
      if (error.response?.statusCode == 401 &&
          !isAuthRequest &&
          !redirectingAfterExpiredToken) {
        redirectingAfterExpiredToken = true;
        await storage.delete(key: _tokenKey);
        _authExpiredController.add(null);
      }
      final status = error.response?.statusCode;
      final kind = switch (status) {
        403 => AppErrorKind.forbidden,
        404 => AppErrorKind.notFound,
        500 || 502 || 503 || 504 => AppErrorKind.server,
        _
            when error.type == DioExceptionType.connectionError ||
                error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout =>
          AppErrorKind.connection,
        _ => null,
      };
      // Individual screens handle connection failures and expose their own
      // retry action. A transient request failure must not replace the whole
      // authenticated application with the global error route.
      if (kind != null &&
          kind != AppErrorKind.connection &&
          !showingGlobalError &&
          !isAuthRequest) {
        showingGlobalError = true;
        _appErrorController.add(AppErrorInfo(kind));
      }
      handler.next(error);
    },
  ));
  return dio;
});
