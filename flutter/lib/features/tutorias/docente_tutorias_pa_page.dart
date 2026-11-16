import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/neu/neu.dart';
import 'proyecto_aula_chat_page.dart';

const _green = Color(0xFF16834A);

/// Proyectos de aula que le tocaron al docente (como tutor asignado).
final _paProjectsProvider =
    FutureProvider.autoDispose<List<_PaProject>>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<List<dynamic>>('/api/docente/tutorias-colectivas');
  return (response.data ?? const [])
      .whereType<Map<String, dynamic>>()
      .where((row) => row['proyecto'] is Map<String, dynamic>)
      .map(_PaProject.fromJson)
      .toList(growable: false);
});

/// Pestaña «Tutorías PA»: un proyecto de aula por tarjeta, cada una con su
/// burbuja de chat. El chat concentra mensajes, notas de voz, documentos y
/// videoconferencias del proyecto.
class DocenteTutoriasPaPage extends ConsumerStatefulWidget {
  const DocenteTutoriasPaPage({super.key});

  @override
  ConsumerState<DocenteTutoriasPaPage> createState() =>
      _DocenteTutoriasPaPageState();
}

class _DocenteTutoriasPaPageState extends ConsumerState<DocenteTutoriasPaPage> {
  String? _openingId;

  /// El chat vive dentro de una «sesión» del proyecto. Se reutiliza la más
  /// reciente; si el proyecto aún no tiene ninguna, se crea una de seguimiento.
  Future<String> _chatSessionId(_PaProject project) async {
    final dio = ref.read(dioProvider);
    final base = '/api/docente/tutorias-colectivas/'
        '${Uri.encodeComponent(project.tutoringId)}'
        '/proyectos/${Uri.encodeComponent(project.projectId)}/sesiones';
    final existing = await dio.get<List<dynamic>>(base);
    final sessions =
        (existing.data ?? const []).whereType<Map<String, dynamic>>();
    if (sessions.isNotEmpty) {
      // El backend las devuelve ordenadas por fechaInicio descendente.
      final id = sessions.first['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    final now = DateTime.now();
    final created = await dio.post<Map<String, dynamic>>(base, data: {
      'fechaInicio': now.toIso8601String(),
      'fechaFin': now.add(const Duration(hours: 1)).toIso8601String(),
      'contenido': 'Chat de seguimiento del proyecto de aula',
    });
    final id = created.data?['id']?.toString();
    if (id == null || id.isEmpty) {
      throw const FormatException('No llegó el identificador del chat.');
    }
    return id;
  }

  Future<void> _openChat(_PaProject project) async {
    if (_openingId != null) return;
    setState(() => _openingId = project.key);
    try {
      final sessionId = await _chatSessionId(project);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProyectoAulaChatPage(
          tutoringId: project.tutoringId,
          projectId: project.projectId,
          sessionId: sessionId,
          title: project.name,
          teacherMode: true,
        ),
      ));
    } on DioException catch (error) {
      _toast(_apiMessage(error));
    } on FormatException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _apiMessage(DioException error) {
    final data = error.response?.data;
    return data is Map && data['message'] is String
        ? data['message'] as String
        : 'No se pudo abrir el chat del proyecto.';
  }

  @override
  Widget build(BuildContext context) =>
      ref.watch(_paProjectsProvider).when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: _green)),
            error: (error, _) => _Centered(
              child: _MessageCard(
                icon: Icons.cloud_off_outlined,
                color: Neu.error,
                title: 'No se pudieron cargar tus proyectos de aula.',
                detail: '$error',
                action: NeuButton(
                  'Reintentar',
                  onPressed: () => ref.invalidate(_paProjectsProvider),
                  kind: NeuButtonKind.alt,
                  small: true,
                  icon: Icons.refresh,
                  expand: false,
                ),
              ),
            ),
            data: (projects) => projects.isEmpty
                ? const _Centered(
                    child: _MessageCard(
                      icon: Icons.school_outlined,
                      color: _green,
                      title: 'No tienes proyectos de aula asignados.',
                      detail:
                          'Cuando coordinación te asigne uno, aparecerá aquí con su chat.',
                    ),
                  )
                : RefreshIndicator(
                    color: _green,
                    onRefresh: () async {
                      ref.invalidate(_paProjectsProvider);
                      await ref.read(_paProjectsProvider.future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(4, 0, 4, 14),
                                  child: Text(
                                    'Toca la burbuja de un proyecto para hablar con sus '
                                    'estudiantes, compartir documentos o crear videoconferencias.',
                                    style:
                                        neuBody(size: 13, color: Neu.muted),
                                  ),
                                ),
                                for (final project in projects)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _ProjectCard(
                                      project: project,
                                      opening: _openingId == project.key,
                                      onChat: () => _openChat(project),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.opening,
    required this.onChat,
  });

  final _PaProject project;
  final bool opening;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) => NeuSurface(
        radius: 20,
        padding: const EdgeInsets.all(16),
        onTap: onChat,
        child: Row(children: [
          const NeuIconBox(Icons.school_outlined, color: _green),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: neuPoppins(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Neu.heading)),
                const SizedBox(height: 3),
                Text(
                  [
                    if (project.technology.isNotEmpty) project.technology,
                    if (project.semester > 0) 'Semestre ${project.semester}',
                    '${project.studentCount} estudiantes',
                  ].join(' · '),
                  style: neuBody(size: 12.5, color: Neu.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          opening
              ? const SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: _green),
                    ),
                  ),
                )
              : NeuCircleButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  tooltip: 'Abrir chat de ${project.name}',
                  onTap: onChat,
                ),
        ]),
      );
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460), child: child),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.color,
    required this.title,
    this.detail,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => NeuSurface(
        radius: 22,
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          NeuIconBox(icon, color: color),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: neuPoppins(
                  size: 15, weight: FontWeight.w700, color: Neu.heading)),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail!,
                textAlign: TextAlign.center,
                style: neuBody(size: 13, color: Neu.muted)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

class _PaProject {
  const _PaProject({
    required this.tutoringId,
    required this.projectId,
    required this.name,
    required this.technology,
    required this.semester,
    required this.studentCount,
  });

  final String tutoringId;
  final String projectId;
  final String name;
  final String technology;
  final int semester;
  final int studentCount;

  String get key => '$tutoringId/$projectId';

  factory _PaProject.fromJson(Map<String, dynamic> json) {
    final project = json['proyecto'] as Map<String, dynamic>;
    final students = project['estudianteIds'];
    return _PaProject(
      tutoringId: json['tutoriaColectivaId']?.toString() ?? '',
      projectId: project['proyectoId']?.toString() ?? '',
      name: project['nombre']?.toString() ?? 'Proyecto de aula',
      technology: project['tecnologia']?.toString() ?? '',
      semester:
          project['semestre'] is num ? (project['semestre'] as num).toInt() : 0,
      studentCount: students is List ? students.length : 0,
    );
  }
}
