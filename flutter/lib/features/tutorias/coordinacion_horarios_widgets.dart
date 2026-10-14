import 'package:flutter/material.dart';

import 'coordinacion_horarios_models.dart';

const _brand = Color(0xFFA9154F);
const _muted = Color(0xFF64748B);

class ScheduleSectionSelector extends StatelessWidget {
  const ScheduleSectionSelector({
    required this.selected,
    required this.scheduleCount,
    required this.onChanged,
    super.key,
  });

  final int selected;
  final int scheduleCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: SegmentedButton<int>(
          segments: [
            const ButtonSegment(
              value: 0,
              icon: Icon(Icons.people_outline),
              label: Text('Docentes'),
            ),
            ButtonSegment(
              value: 1,
              icon: const Icon(Icons.event_available_outlined),
              label: Text('Horarios creados ($scheduleCount)'),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (selection) => onChanged(selection.first),
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
    super.key,
  });

  final TextEditingController searchController;
  final List<String> careers;
  final String career;
  final int? semester;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCareerChanged;
  final ValueChanged<int?> onSemesterChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final search = TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar tutor por nombre o ID',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: _border(),
                enabledBorder: _border(),
              ),
            );
            final careerFilter = DropdownButtonFormField<String>(
              initialValue: career,
              decoration: const InputDecoration(
                labelText: 'Carrera',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: careers
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) {
                if (value != null) onCareerChanged(value);
              },
            );
            final semesterFilter = DropdownButtonFormField<int?>(
              initialValue: semester,
              decoration: const InputDecoration(
                labelText: 'Semestre',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Todos'),
                ),
                for (var item = 1; item <= 12; item++)
                  DropdownMenuItem<int?>(value: item, child: Text('$item')),
              ],
              onChanged: onSemesterChanged,
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
                      SizedBox(width: 140, child: semesterFilter),
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
              ],
            );
          },
        ),
      );

  OutlineInputBorder _border() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      );
}

class TeacherScheduleGrid extends StatelessWidget {
  const TeacherScheduleGrid({
    required this.teachers,
    required this.schedules,
    required this.onSelect,
    required this.onDelete,
    super.key,
  });

  final List<Teacher> teachers;
  final Map<String, TutorSchedule> schedules;
  final ValueChanged<Teacher> onSelect;
  final ValueChanged<Teacher> onDelete;

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
              mainAxisExtent: 190,
            ),
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              return _TeacherCard(
                teacher: teacher,
                schedule: schedules[teacher.id],
                onTap: () => onSelect(teacher),
                onDelete: () => onDelete(teacher),
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
    required this.onTap,
    required this.onDelete,
  });

  final Teacher teacher;
  final TutorSchedule? schedule;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final assigned = schedule != null;
    final currentSchedule = schedule;
    final subjectSummary = currentSchedule == null
        ? ''
        : currentSchedule.materias.map((subject) {
            final sharedCareers = subject.carreras
                .where((career) => career != currentSchedule.carrera)
                .join(', ');
            return '${subject.nombre} (${sharedCareers.isEmpty ? 'Exclusiva' : 'Compartida con $sharedCareers'})';
          }).join(', ');
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE7EF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_outline, color: _brand),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text('ID ${teacher.id}',
                          style: const TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                ),
                _ScheduleBadge(assigned: assigned),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                assigned
                    ? '${schedule!.carrera} · Semestre ${schedule!.semestre}\n'
                        '${schedule!.dia} · ${schedule!.horaInicio}–${schedule!.horaFin} · ${schedule!.modalidad}'
                        '${subjectSummary.isEmpty ? '' : '\nMaterias: $subjectSummary'}'
                    : 'Aún no se ha registrado disponibilidad para este tutor.',
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, height: 1.4),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (assigned)
                  IconButton(
                    tooltip: 'Eliminar horario',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                FilledButton(
                  onPressed: onTap,
                  child: Text(assigned ? 'Editar' : 'Asignar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleBadge extends StatelessWidget {
  const _ScheduleBadge({required this.assigned});

  final bool assigned;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: assigned ? const Color(0xFFDCFCE7) : const Color(0xFFFFF1E6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          assigned ? 'Asignado' : 'Sin horario',
          style: TextStyle(
            color: assigned ? const Color(0xFF15803D) : const Color(0xFFC2410C),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      );
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
}

class ScheduleEmptyResults extends StatelessWidget {
  const ScheduleEmptyResults({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay tutores que coincidan con los filtros seleccionados.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ),
      );
}
