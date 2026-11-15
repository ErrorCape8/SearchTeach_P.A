import 'package:flutter/material.dart';

import '../pa/pa_widgets.dart';
import 'coordinacion_horarios_models.dart';

const _brand = Color(0xFFA9154F);

class ScheduleSectionSelector extends StatelessWidget {
  const ScheduleSectionSelector({
    required this.selected,
    required this.withScheduleCount,
    required this.withoutScheduleCount,
    required this.onChanged,
    super.key,
  });

  final int selected;
  final int withScheduleCount;
  final int withoutScheduleCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: PaSegmented(
            labels: [
              'Asignados ($withScheduleCount)',
              'No asignados ($withoutScheduleCount)',
            ],
            selected: selected,
            onSelect: onChanged,
          ),
        ),
      );
}

class ScheduleFilters extends StatelessWidget {
  const ScheduleFilters({
    required this.searchController,
    required this.careers,
    required this.career,
    required this.semester,
    required this.onSearchChanged,
    required this.onCareerChanged,
    required this.onSemesterChanged,
    required this.onRefresh,
    this.refreshing = false,
    super.key,
  });

  final TextEditingController searchController;
  final List<String> careers;
  final String career;
  final int? semester;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCareerChanged;
  final ValueChanged<int?> onSemesterChanged;
  final VoidCallback onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final search = NeuField(
              controller: searchController,
              hint: 'Buscar tutor por nombre o ID',
              onChanged: onSearchChanged,
            );
            final careerFilter = NeuDropdown<String>(
              items: careers,
              value: career,
              labelOf: (v) => v == 'Todas' ? 'Carrera: Todas' : v,
              onChanged: (v) {
                if (v != null) onCareerChanged(v);
              },
            );
            final semesterFilter = NeuDropdown<String>(
              items: [
                'Todos',
                for (var item = 1; item <= 12; item++) '$item',
              ],
              value: semester == null ? 'Todos' : '$semester',
              labelOf: (v) => v == 'Todos' ? 'Semestre: Todos' : 'Semestre $v',
              onChanged: (v) => onSemesterChanged(
                  v == null || v == 'Todos' ? null : int.tryParse(v)),
            );
            final refreshButton = NeuButton(
              'Actualizar',
              onPressed: refreshing ? null : onRefresh,
              kind: NeuButtonKind.alt,
              small: true,
              expand: false,
              icon: Icons.refresh_rounded,
            );

            if (constraints.maxWidth < 650) {
              return Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: careerFilter),
                      const SizedBox(width: 10),
                      SizedBox(width: 135, child: semesterFilter),
                      const SizedBox(width: 8),
                      NeuCircleButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Actualizar',
                        onTap: refreshing ? null : onRefresh,
                      ),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 5, child: search),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: careerFilter),
                const SizedBox(width: 12),
                SizedBox(width: 180, child: semesterFilter),
                const SizedBox(width: 12),
                refreshButton,
              ],
            );
          },
        ),
      );
}

class TeacherScheduleGrid extends StatelessWidget {
  const TeacherScheduleGrid({
    required this.teachers,
    required this.schedules,
    required this.sessions,
    required this.onEditSession,
    required this.onDeleteSession,
    required this.onEditSchedule,
    super.key,
  });

  final List<Teacher> teachers;
  final Map<String, TutorSchedule> schedules;
  final Map<String, List<PublishedTutoringSession>> sessions;
  final ValueChanged<PublishedTutoringSession> onEditSession;
  final ValueChanged<PublishedTutoringSession> onDeleteSession;
  final void Function(Teacher teacher, TutorSchedule? schedule) onEditSchedule;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 940
              ? 3
              : constraints.maxWidth >= 620
                  ? 2
                  : 1;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 295,
            ),
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              return _TeacherCard(
                teacher: teacher,
                schedule: schedules[teacher.id],
                sessions: sessions[teacher.id] ?? const [],
                onEditSession: onEditSession,
                onDeleteSession: onDeleteSession,
                onEditSchedule: onEditSchedule,
              );
            },
          );
        },
      );
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({
    required this.teacher,
    required this.schedule,
    required this.sessions,
    required this.onEditSession,
    required this.onDeleteSession,
    required this.onEditSchedule,
  });

  final Teacher teacher;
  final TutorSchedule? schedule;
  final List<PublishedTutoringSession> sessions;
  final ValueChanged<PublishedTutoringSession> onEditSession;
  final ValueChanged<PublishedTutoringSession> onDeleteSession;
  final void Function(Teacher teacher, TutorSchedule? schedule) onEditSchedule;

  @override
  Widget build(BuildContext context) {
    final assigned = schedule != null;
    final hasAvailability = assigned || sessions.isNotEmpty;
    return NeuSurface(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const NeuIconBox(
                Icons.person_outline,
                size: 44,
                radius: 14,
                iconSize: 22,
                color: _brand,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.nombre.isEmpty ? 'Docente' : teacher.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: neuPoppins(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Neu.heading,
                      ),
                    ),
                    Text(
                      'ID ${teacher.id}',
                      style: neuBody(color: Neu.muted, size: 12),
                    ),
                  ],
                ),
              ),
              PaTag(
                hasAvailability ? 'Asignado' : 'No asignado',
                tone: hasAvailability ? PaTone.ok : PaTone.warn,
              ),
              const SizedBox(width: 4),
              NeuCircleButton(
                size: 36,
                icon: Icons.edit_calendar_outlined,
                tooltip: schedule == null ? 'Asignar horario' : 'Editar horario',
                onTap: () => onEditSchedule(teacher, schedule),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            assigned
                ? '${schedule!.carrera} · Semestre ${schedule!.semestre} · ${schedule!.dia} ${schedule!.horaInicio}–${schedule!.horaFin}'
                : sessions.isNotEmpty
                    ? 'Tiene ${sessions.length} tutoría(s) publicada(s).'
                    : 'Este docente aún no tiene tutorías asignadas.',
            style: neuBody(color: Neu.muted, height: 1.4, size: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          for (final session in sessions.take(3)) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${session.subject} · ${_sessionDateTime(session)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: neuBody(color: Neu.muted, size: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Editar tutoría',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () => onEditSession(session),
                  icon: const Icon(Icons.edit_outlined,
                      size: 16, color: Neu.muted),
                ),
                IconButton(
                  tooltip: 'Eliminar tutoría',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () => onDeleteSession(session),
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Neu.error),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _sessionDateTime(PublishedTutoringSession session) {
    final start = session.start?.toLocal();
    if (start == null) return 'Fecha pendiente';
    final date =
        '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';
    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final modality = session.modality.isEmpty ? '' : ' · ${session.modality}';
    final location = session.location.isEmpty ? '' : ' · ${session.location}';
    return '$date $time$modality$location';
  }
}

class ScheduleLoadError extends StatelessWidget {
  const ScheduleLoadError({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PaInfo(message, tone: PaTone.error, icon: Icons.error_outline),
                const SizedBox(height: 14),
                NeuButton(
                  'Reintentar',
                  onPressed: onRetry,
                  kind: NeuButtonKind.alt,
                  small: true,
                  expand: false,
                  icon: Icons.refresh_rounded,
                ),
              ],
            ),
          ),
        ),
      );
}

class ScheduleEmptyResults extends StatelessWidget {
  const ScheduleEmptyResults({super.key});

  @override
  Widget build(BuildContext context) =>
      const PaEmpty('No hay tutores que coincidan con los filtros seleccionados.');
}
