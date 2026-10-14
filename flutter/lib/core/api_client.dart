import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Android emulator: 10.0.2.2 = tu PC. iOS simulator / web: localhost.
/// Celular físico: usa la IP de tu PC (ej. http://192.168.1.20:8081).
const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

String get baseUrl {
  if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
  if (kIsWeb) return 'http://localhost:8081';
  return Platform.isAndroid ? 'http://10.0.2.2:8081' : 'http://localhost:8081';
}

const _tokenKey = 'token';

final secureStorageProvider = Provider((_) => const FlutterSecureStorage());

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  // Agrega el JWT a todas las llamadas protegidas.
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      if (!options.path.startsWith('/api/auth')) {
        final token = await storage.read(key: _tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  ));
  return dio;
});
