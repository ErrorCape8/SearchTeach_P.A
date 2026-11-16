import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/neu/neu.dart';
import 'docente_lider_proyectos_page.dart';
import '../pa/pa_widgets.dart' show PaTag, PaTone;

const _teacherGreen = Color(0xFF16834A);

final _teacherSupportProjectsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<List<dynamic>>('/api/docente/tutorias-colectivas');
  final data = response.data;
  if (data == null) {
    throw const FormatException(
      'El servidor no devolvió los grupos de proyecto del docente.',
    );
  }
  return data
      .whereType<Map<String, dynamic>>()
      .where((row) => row['proyecto'] is Map<String, dynamic>)
      .toList(growable: false);
});

final _teacherProjectReportsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (String tutoringId, String projectId)>(
  (ref, key) async {
    final response = await ref.read(dioProvider).get<List<dynamic>>(
          '/api/docente/tutorias-colectivas/'
          '${Uri.encodeComponent(key.$1)}/proyectos/'
          '${Uri.encodeComponent(key.$2)}/sesiones',
        );
    final data = response.data;
    if (data == null) {
      throw const FormatException(
        'El servidor no devolvió los reportes del proyecto.',
      );
    }
    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  },
);

class DocenteGruposReportesSection extends ConsumerWidget {
  const DocenteGruposReportesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supportProjects = ref.watch(_teacherSupportProjectsProvider);
    final leaderAssignments = ref.watch(teacherLeaderAssignmentsProvider);
    final supportGroups = supportProjects.when(
      data: _groupSupportProjects,
      loading: () => null,
      error: (_, __) => null,
    );
    final leaderGroups = leaderAssignments.when(
      data: _groupLeaderAssignments,
      loading: () => null,
      error: (_, __) => null,
    );
    final showSupport = supportProjects.isLoading ||
        supportProjects.hasError ||
        supportGroups?.isNotEmpty == true;
    final showLeader = leaderAssignments.isLoading ||
        leaderAssignments.hasError ||
        leaderGroups?.isNotEmpty == true;
    if (!showSupport && !showLeader) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proyectos de aula vigentes',
          style: neuPoppins(
            size: 18,
            weight: FontWeight.w700,
            color: Neu.heading,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Consulta tus grupos de apoyo y liderazgo, y abre sus reportes.',
          style: neuBody(size: 13, color: Neu.muted),
        ),
        const SizedBox(height: 14),
        if (showSupport)
          _groupCards(
            context,
            title: 'Como tutor de apoyo',
            groups: supportGroups,
            loading: supportProjects.isLoading,
            error: supportProjects.error,
            onRetry: () => ref.invalidate(_teacherSupportProjectsProvider),
          ),
        if (showSupport && showLeader) const SizedBox(height: 14),
        if (showLeader)
          _groupCards(
            context,
            title: 'Como docente líder',
            groups: leaderGroups,
            loading: leaderAssignments.isLoading,
            error: leaderAssignments.error,
            onRetry: () => ref.invalidate(teacherLeaderAssignmentsProvider),
          ),
      ],
    );
  }

  Widget _groupCards(
    BuildContext context, {
    required String title,
    required List<_ProjectGroupSummary>? groups,
    required bool loading,
    required Object? error,
    required VoidCallback onRetry,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: neuPoppins(
                size: 14, weight: FontWeight.w700, color: Neu.heading)),
        const SizedBox(height: 9),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child:
                Center(child: CircularProgressIndicator(color: _teacherGreen)),
          )
        else if (error != null)
          _GroupLoadError(error: error, onRetry: onRetry)
        else if (groups == null || groups.isEmpty)
          const SizedBox.shrink()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth >= 580
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final group in groups)
                    SizedBox(
                      width: width,
                      child: _ProjectGroupCard(group: group),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _ProjectGroupCard extends StatelessWidget {
  const _ProjectGroupCard({required this.group});

  final _ProjectGroupSummary group;

  @override
  Widget build(BuildContext context) => NeuSurface(
        radius: 18,
        padding: const EdgeInsets.all(14),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _ProjectReportsDialog(group: group),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const NeuIconBox(Icons.groups_outlined,
                    color: _teacherGreen, size: 38, iconSize: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: neuPoppins(
                      size: 13,
                      weight: FontWeight.w700,
                      color: Neu.heading,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Neu.chevron, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${group.projects.length} ${group.projects.length == 1 ? 'proyecto' : 'proyectos'} · '
              '${group.studentCount} ${group.studentCount == 1 ? 'estudiante' : 'estudiantes'}',
              style: neuBody(size: 12, color: Neu.muted),
            ),
            if (group.supportNames.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                'Docentes de apoyo: ${group.supportNames.join(', ')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: neuBody(size: 11.5, color: Neu.muted),
              ),
            ],
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final project in group.projects.take(2))
                  _ProjectNameTag(
                    project['nombre']?.toString() ?? 'Proyecto de aula',
                  ),
                if (group.projects.length > 2)
                  _ProjectNameTag('+${group.projects.length - 2} más'),
              ],
            ),
          ],
        ),
      );
}

class _ProjectNameTag extends StatelessWidget {
  const _ProjectNameTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Neu.quietBg,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: neuBody(size: 10.5, weight: FontWeight.w600, color: Neu.text),
        ),
      );
}

class _GroupLoadError extends StatelessWidget {
  const _GroupLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => NeuSurface(
        radius: 14,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: Neu.error, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No se pudieron cargar estos grupos: $error',
                style: neuBody(size: 12, color: Neu.muted),
              ),
            ),
            NeuCircleButton(
              size: 34,
              icon: Icons.refresh_rounded,
              tooltip: 'Reintentar',
              onTap: onRetry,
            ),
          ],
        ),
      );
}

class _ProjectReportsDialog extends StatelessWidget {
  const _ProjectReportsDialog({required this.group});

  final _ProjectGroupSummary group;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 680,
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: NeuSurface(
            radius: 22,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.title,
                            style: neuPoppins(
                              size: 17,
                              weight: FontWeight.w700,
                              color: Neu.heading,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${group.role} · ${group.projects.length} proyectos',
                            style: neuBody(size: 12, color: Neu.muted),
                          ),
                        ],
                      ),
                    ),
                    NeuCircleButton(
                      size: 36,
                      icon: Icons.close_rounded,
                      tooltip: 'Cerrar',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    children: [
                      for (final project in group.projects)
                        _ProjectReportsPanel(
                          tutoringId: group.tutoringId,
                          project: project,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ProjectReportsPanel extends ConsumerWidget {
  const _ProjectReportsPanel({
    required this.tutoringId,
    required this.project,
  });

  final String tutoringId;
  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = project['proyectoId']?.toString() ?? '';
    final report = project['reporteCierre']?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuSurface(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project['nombre']?.toString() ?? 'Proyecto de aula',
              style: neuPoppins(
                size: 14,
                weight: FontWeight.w700,
                color: Neu.heading,
              ),
            ),
            const SizedBox(height: 6),
            if (report.isNotEmpty) ...[
              const PaTag('Reporte de cierre', tone: PaTone.ok),
              const SizedBox(height: 7),
              SelectableText(report,
                  style: neuBody(size: 12.5, color: Neu.text, height: 1.4)),
              const SizedBox(height: 10),
            ],
            ref
                .watch(
                  _teacherProjectReportsProvider((tutoringId, projectId)),
                )
                .when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(color: _teacherGreen),
                  ),
                  error: (error, _) => Text(
                    'No se pudieron cargar los reportes de este proyecto: $error',
                    style: neuBody(size: 12, color: Neu.error),
                  ),
                  data: (sessions) => sessions.isEmpty
                      ? Text(
                          report.isEmpty
                              ? 'Este proyecto aún no tiene reportes de sesión.'
                              : 'No hay reportes de sesión adicionales.',
                          style: neuBody(size: 12, color: Neu.muted),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reportes de sesión',
                              style: neuBody(
                                size: 12,
                                weight: FontWeight.w700,
                                color: Neu.heading,
                              ),
                            ),
                            const SizedBox(height: 5),
                            for (final session in sessions)
                              Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: NeuSunken(
                                  radius: 11,
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _dateLabel(session['fechaInicio']),
                                        style: neuBody(
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color: _teacherGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      SelectableText(
                                        session['contenido']?.toString() ?? '',
                                        style: neuBody(
                                          size: 12,
                                          color: Neu.text,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ProjectGroupSummary {
  const _ProjectGroupSummary({
    required this.tutoringId,
    required this.title,
    required this.role,
    required this.projects,
    required this.supportNames,
    required this.studentCount,
  });

  final String tutoringId;
  final String title;
  final String role;
  final List<Map<String, dynamic>> projects;
  final List<String> supportNames;
  final int studentCount;
}

List<_ProjectGroupSummary> _groupSupportProjects(
    List<Map<String, dynamic>> rows) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final tutoringId = row['tutoriaColectivaId']?.toString() ?? '';
    final project = row['proyecto'];
    if (tutoringId.isEmpty || project is! Map<String, dynamic>) continue;
    grouped.putIfAbsent(tutoringId, () => []).add(project);
  }
  return [
    for (final entry in grouped.entries)
      _ProjectGroupSummary(
        tutoringId: entry.key,
        title: _groupTitle(entry.value),
        role: 'Tutor de apoyo',
        projects: entry.value,
        supportNames: const [],
        studentCount: _studentCount(entry.value),
      ),
  ];
}

List<_ProjectGroupSummary> _groupLeaderAssignments(
    List<Map<String, dynamic>> rows) {
  final active = rows.where((row) => row['estado']?.toString() == 'ACTIVA');
  return [
    for (final row in active)
      if ((row['id']?.toString() ?? '').isNotEmpty)
        _ProjectGroupSummary(
          tutoringId: row['id'].toString(),
          title: _groupTitle(
            (row['proyectos'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false),
            fallbackTechnology: row['tecnologia']?.toString(),
            fallbackSemester: row['semestre'],
          ),
          role: 'Docente líder',
          projects: (row['proyectos'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false),
          supportNames: (row['docentesApoyo'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map((teacher) => teacher['nombre']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList(growable: false),
          studentCount: _studentCount(
            (row['proyectos'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false),
          ),
        ),
  ];
}

String _groupTitle(
  List<Map<String, dynamic>> projects, {
  String? fallbackTechnology,
  dynamic fallbackSemester,
}) {
  final technology = projects.isNotEmpty
      ? projects.first['tecnologia']?.toString()
      : fallbackTechnology;
  final semester =
      projects.isNotEmpty ? projects.first['semestre'] : fallbackSemester;
  final career =
      technology == null || technology.isEmpty ? 'Grupo PA' : technology;
  return semester is num && semester > 0
      ? '$career · Semestre ${semester.toInt()}'
      : career;
}

int _studentCount(List<Map<String, dynamic>> projects) => projects
    .expand((project) =>
        (project['estudianteIds'] as List? ?? const []).whereType<String>())
    .toSet()
    .length;

String _dateLabel(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Fecha no disponible';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
