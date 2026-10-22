import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../notifications/notification_push_service.dart';

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

  Future<void> verifyRegistration(String identifier) async {
    try {
      await _dio.post<void>(
        '/api/auth/register/verify',
        data: {'identifier': identifier},
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        throw AuthFailure(
          data['message'] as String,
          retryAfterSeconds: (data['retryAfterSeconds'] ?? 0) as int,
        );
      }
      throw AuthFailure(
        'No se pudo conectar con el servidor (${error.requestOptions.uri.host}:${error.requestOptions.uri.port}).',
      );
    }
  }

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

  Future<String?> currentRole() async {
    final token = await _ref.read(secureStorageProvider).read(key: 'token');
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('El token de sesión no tiene un formato válido.');
    }
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map<String, dynamic> || payload['role'] is! String) {
      throw const FormatException('El token de sesión no contiene un rol válido.');
    }
    return payload['role'] as String;
  }

  Future<String> landingRoute() async {
    final role = await currentRole();
    switch (role) {
      case 'ADMIN':
        return '/admin';
      case 'COORDINATOR':
        return '/coordinacion';
      case 'DIRECTOR':
        return '/home';
      case 'USER':
        try {
          final response = await _dio.get<Map<String, dynamic>>(
            '/api/usuarios/perfil',
          );
          final profileRole = response.data?['rol'];
          if (profileRole is! String || profileRole.trim().isEmpty) {
            throw AuthFailure('La cuenta no tiene un perfil académico válido.');
          }
          final normalized = profileRole.toLowerCase();
          if (normalized.contains('estudiante')) return '/estudiante';
          if (normalized.contains('docente')) return '/docente';
          throw AuthFailure('No reconocemos el rol académico de esta cuenta.');
        } on DioException catch (error) {
          debugPrint('PROFILE ERROR -> ${error.message}');
          throw AuthFailure(
            'No se pudo cargar el perfil de la cuenta. Inténtalo de nuevo.',
          );
        }
      default:
        throw AuthFailure('El rol de esta cuenta no es válido.');
    }
  }

  Future<void> logout() async {
    try {
      await disableDeviceNotifications(_dio);
    } catch (_) {
      // A push token must not prevent the user from ending the session.
    }
    await _ref.read(secureStorageProvider).delete(key: 'token');
  }
}

final authRepositoryProvider =
    Provider((ref) => AuthRepository(ref.read(dioProvider), ref));
