import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

final tutoringUpdatesProvider =
    StreamProvider.autoDispose<String>((ref) async* {
  final cancel = CancelToken();
  ref.onDispose(() => cancel.cancel('Pantalla cerrada'));
  while (!cancel.isCancelled) {
    try {
      final response = await ref.read(dioProvider).get<ResponseBody>(
            '/api/tutorias/eventos',
            cancelToken: cancel,
            options: Options(
              responseType: ResponseType.stream,
              receiveTimeout: Duration.zero,
            ),
          );
      final body = response.data;
      if (body == null) return;
      await for (final line
          in body.stream.map(utf8.decode).transform(const LineSplitter())) {
        if (line.startsWith('data:')) {
          final data = line.substring(5).trim();
          if (data.isNotEmpty && data != 'connected') yield data;
        }
      }
    } on DioException {
      if (cancel.isCancelled) return;
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }
});
