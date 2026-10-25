import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'proyecto_aula_chat_page.dart';

final _leaderProjectsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.read(dioProvider).get<List<dynamic>>(
        '/api/docente/tutorias-colectivas/lider',
      );
  return (response.data ?? const []).whereType<Map<String, dynamic>>().toList();
});

final _leaderSessionsProvider = FutureProvider.autoDispose.family<
    List<Map<String, dynamic>>, (String tutoringId, String projectId)>((ref, key) async {
  final response = await ref.read(dioProvider).get<List<dynamic>>(
    '/api/docente/tutorias-colectivas/${Uri.encodeComponent(key.$1)}'
    '/proyectos/${Uri.encodeComponent(key.$2)}/sesiones',
  );
  return (response.data ?? const []).whereType<Map<String, dynamic>>().toList();
});

class DocenteLiderProyectosPage extends ConsumerWidget {
  const DocenteLiderProyectosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_leaderProjectsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('No se pudieron cargar los reportes: $error')),
        data: (items) {
          final projects = items.where((row) => row['proyecto'] is Map<String, dynamic>).toList();
          if (projects.isEmpty) {
            return const Center(child: Text('No tienes proyectos de aula para revisar como docente líder.'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Revisión de proyectos de aula', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Revisa los reportes del tutor de apoyo y confirma o devuelve las solicitudes de cierre.'),
              const SizedBox(height: 14),
              for (final row in projects)
                _LeaderProjectCard(
                  row: row,
                  onChanged: () => ref.invalidate(_leaderProjectsProvider),
                ),
            ],
          );
        },
      );
}

class _LeaderProjectCard extends ConsumerWidget {
  const _LeaderProjectCard({required this.row, required this.onChanged});
  final Map<String, dynamic> row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = row['proyecto'] as Map<String, dynamic>;
    final tutoringId = row['tutoriaColectivaId']?.toString() ?? '';
    final projectId = project['proyectoId']?.toString() ?? '';
    final state = project['estadoCierre']?.toString() ?? 'EN_CURSO';
    final pending = state == 'PENDIENTE_CONFIRMACION';
    final closed = state == 'FINALIZADO';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(project['nombre']?.toString() ?? 'Proyecto de aula', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text('Tutor de apoyo: ${project['docenteResponsableId'] ?? 'Sin asignar'} · Estado: ${closed ? 'Finalizado' : pending ? 'Pendiente de confirmación' : 'En curso'}'),
          if (project['motivoCierre'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(project['motivoCierre'] == 'SIN_ATENCION'
                  ? 'Motivo: estudiantes sin atención o respuesta.'
                  : 'Motivo: proyecto listo.'),
            ),
          if (project['fechaReunion'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Reunión: ${_dateTime(project['fechaReunion'])}'),
            ),
          const SizedBox(height: 8),
          _LeaderReportsList(tutoringId: tutoringId, project: project),
          if (pending) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: () => _respond(context, ref, tutoringId, projectId, true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar cierre'),
              ),
              OutlinedButton.icon(
                onPressed: () => _respond(context, ref, tutoringId, projectId, false),
                icon: const Icon(Icons.undo_outlined),
                label: const Text('Devolver al tutor'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _respond(BuildContext context, WidgetRef ref, String tutoringId,
      String projectId, bool confirm) async {
    try {
      await ref.read(dioProvider).post(
        '/api/docente/lider/tutorias-colectivas/${Uri.encodeComponent(tutoringId)}'
        '/proyectos/${Uri.encodeComponent(projectId)}/confirmacion-cierre',
        queryParameters: {'confirmar': confirm},
      );
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(confirm ? 'Cierre confirmado.' : 'Solicitud devuelta al tutor.'),
        ));
      }
    } on DioException catch (error) {
      final data = error.response?.data;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data is Map && data['message'] is String
              ? data['message'] as String
              : 'No se pudo guardar la respuesta.'),
        ));
      }
    }
  }
}

class _LeaderReportsList extends ConsumerWidget {
  const _LeaderReportsList({required this.tutoringId, required this.project});
  final String tutoringId;
  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = project['proyectoId']?.toString() ?? '';
    return ref.watch(_leaderSessionsProvider((tutoringId, projectId))).when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('No se pudieron cargar las sesiones reportadas: $error'),
      data: (sessions) => sessions.isEmpty
          ? const Text('El tutor todavía no ha guardado reportes de sesión.')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Reportes del tutor', style: TextStyle(fontWeight: FontWeight.w700)),
              for (final session in sessions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(_dateTime(session['fechaInicio'])),
                  subtitle: Text('${session['contenido']?.toString() ?? ''}\n${session['confirmadoPorLiderId'] == null ? 'Pendiente de confirmación' : 'Trabajo confirmado'}', maxLines: 4, overflow: TextOverflow.ellipsis),
                  trailing: session['confirmadoPorLiderId'] == null
                      ? IconButton(
                          tooltip: 'Confirmar trabajo realizado',
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () async {
                            try {
                              await ref.read(dioProvider).post(
                                '/api/docente/lider/tutorias-colectivas/${Uri.encodeComponent(tutoringId)}'
                                '/proyectos/${Uri.encodeComponent(projectId)}'
                                '/sesiones/${Uri.encodeComponent(session['id']?.toString() ?? '')}/confirmacion',
                              );
                              ref.invalidate(_leaderSessionsProvider((tutoringId, projectId)));
                            } on DioException catch (error) {
                              final data = error.response?.data;
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(data is Map && data['message'] is String
                                      ? data['message'] as String
                                      : 'No se pudo confirmar el reporte.'),
                                ));
                              }
                            }
                          },
                        )
                      : const Icon(Icons.verified_outlined, color: Colors.green),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProyectoAulaChatPage(
                      tutoringId: tutoringId,
                      projectId: projectId,
                      sessionId: session['id']?.toString() ?? '',
                      title: project['nombre']?.toString() ?? 'Proyecto de aula',
                      teacherMode: true,
                      supportMode: false,
                    ),
                  )),
                ),
            ]),
    );
  }
}

String _dateTime(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Fecha no disponible';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
