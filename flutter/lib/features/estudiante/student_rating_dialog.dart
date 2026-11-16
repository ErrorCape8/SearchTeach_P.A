import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/widgets/role_toast.dart';
import 'student_dashboard_models.dart';

Future<void> showStudentTutoringRatingDialog(
  BuildContext context,
  WidgetRef ref, {
  required String sessionId,
  String? subject,
}) async {
  var stars = 0;
  final selectedComments = <String>{};

  List<String> getComments(int s) => switch (s) {
        1 => const [
            'El tutor no se presentó',
            'El tutor no ingresó',
            'El tutor no explicó bien',
          ],
        2 => const [
            'El tutor llegó tarde',
            'La explicación fue poco clara',
            'Necesité más apoyo del tutor',
          ],
        3 => const [
            'La clase estuvo bien',
            'El tutor explicó lo básico',
            'El tutor podría mejorar',
          ],
        4 => const [
            'El tutor explicó claramente',
            'Buena atención del tutor',
            'El tutor resolvió mis dudas',
          ],
        5 => const [
            'Excelente explicación del tutor',
            'El tutor fue atento y claro',
            'Recomiendo a este tutor',
          ],
        _ => const [],
      };

  final result = await showDialog<(int, String)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, refresh) {
        final options = getComments(stars);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            subject != null && subject.isNotEmpty
                ? '¿Cómo estuvo tu tutoría de $subject?'
                : '¿Cómo sentiste la atención del tutor?',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        tooltip: '$i estrellas',
                        onPressed: () => refresh(() {
                          stars = i;
                          selectedComments.clear();
                        }),
                        icon: Icon(
                          i <= stars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 36,
                        ),
                      ),
                  ],
                ),
                if (stars > 0) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Comentarios sobre la sesión:',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in options)
                        FilterChip(
                          label: Text(option),
                          selected: selectedComments.contains(option),
                          selectedColor: const Color(0xFFD6E4FF),
                          checkmarkColor: const Color(0xFF1769AA),
                          labelStyle: TextStyle(
                            color: selectedComments.contains(option)
                                ? const Color(0xFF1769AA)
                                : const Color(0xFF263238),
                            fontSize: 12,
                            fontWeight: selectedComments.contains(option)
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          onSelected: (selected) => refresh(() {
                            if (selected) {
                              selectedComments.add(option);
                            } else {
                              selectedComments.remove(option);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Omitir', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1769AA),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: stars == 0
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        (
                          stars,
                          selectedComments.isEmpty
                              ? ''
                              : '${selectedComments.join('. ')}.',
                        ),
                      ),
              child: const Text('Enviar calificación'),
            ),
          ],
        );
      },
    ),
  );

  if (result == null || !context.mounted) return;

  try {
    await ref.read(dioProvider).post(
      '/api/tutorias/grupales/${Uri.encodeComponent(sessionId)}/valoracion',
      data: {'estrellas': result.$1, 'comentario': result.$2},
    );
    if (context.mounted) {
      RoleToast.show(
        context,
        message: '¡Gracias por calificar la tutoría!',
        roleColor: const Color(0xFF1769AA),
      );
      ref.invalidate(studentGroupSessionsProvider);
    }
  } on DioException catch (error) {
    if (!context.mounted) return;
    final data = error.response?.data;
    final message = data is Map && data['message'] is String
        ? data['message'] as String
        : 'No se pudo enviar la calificación.';
    RoleToast.show(context,
        message: message, roleColor: const Color(0xFF1769AA));
  }
}

Future<void> showStudentTutoringRatingIfNeeded(
  BuildContext context,
  WidgetRef ref, {
  required String sessionId,
  required String studentId,
  required String subject,
}) async {
  try {
    final response = await ref.read(dioProvider).get<Map<String, dynamic>>(
          '/api/tutorias/grupales/${Uri.encodeComponent(sessionId)}',
        );
    final session = response.data;
    if (session?['estadoClase'] != 'FINALIZADA') return;
    final ratings = session?['valoraciones'];
    final alreadyRated = ratings is List &&
        ratings
            .whereType<Map<String, dynamic>>()
            .any((rating) => rating['estudianteId']?.toString() == studentId);
    if (alreadyRated || !context.mounted) return;

    await showStudentTutoringRatingDialog(
      context,
      ref,
      sessionId: sessionId,
      subject: subject,
    );
  } on DioException catch (error) {
    if (!context.mounted) return;
    final data = error.response?.data;
    final message = data is Map && data['message'] is String
        ? data['message'] as String
        : 'No se pudo comprobar si la tutoría ya finalizó.';
    RoleToast.show(context,
        message: message, roleColor: const Color(0xFF1769AA));
  }
}
