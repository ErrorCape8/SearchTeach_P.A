import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

/// Error que viene del backend: {message, retryable, retryAfterSeconds}
class AuthFailure implements Exception {
  AuthFailure(this.message, {this.retryAfterSeconds = 0});
  final String message;
  final int retryAfterSeconds;
  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._dio, this._ref);
  final Dio _dio;
  final Ref _ref;

  Future<void> login(String identifier, String password) =>
      _authenticate('/api/auth/login', identifier, password);

  Future<void> register(String identifier, String password) =>
      _authenticate('/api/auth/register', identifier, password);

  Future<void> _authenticate(String path, String id, String pass) async {
    try {
      final res = await _dio.post(path, data: {
        'identifier': id,
        'password': pass,
      });
      // AuthResponse: { token, tokenType, expiresInSeconds }
      await _ref
          .read(secureStorageProvider)
          .write(key: 'token', value: res.data['token'] as String);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw AuthFailure(
          data['message'] as String,
          retryAfterSeconds: (data['retryAfterSeconds'] ?? 0) as int,
        );
      }
      debugPrint(
          'AUTH ERROR -> ${e.type} | ${e.message} | URL: ${e.requestOptions.uri}');
      throw AuthFailure(
          'No se pudo conectar con el servidor (${e.requestOptions.uri.host}:${e.requestOptions.uri.port}).');
    }
  }

  Future<bool> hasSession() async =>
      await _ref.read(secureStorageProvider).read(key: 'token') != null;

  Future<void> logout() =>
      _ref.read(secureStorageProvider).delete(key: 'token');
}

final authRepositoryProvider =
    Provider((ref) => AuthRepository(ref.read(dioProvider), ref));
