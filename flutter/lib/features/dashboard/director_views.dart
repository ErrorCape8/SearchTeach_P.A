import 'package:flutter/material.dart';

import '../../core/career_catalog.dart';
import '../calidad/calidad_panel.dart';
import '../pa/pa_widgets.dart';
import 'director_dashboard_provider.dart';
import 'director_widgets.dart';

String _dm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

String _pct(double? value) => value == null ? '—' : '${value.round()}%';

// ═════════════════════════════════════════════════════════════════════════════
//  INICIO
// ═════════════════════════════════════════════════════════════════════════════

class DirHomeView extends StatelessWidget {
  const DirHomeView({
    required this.data,
    required this.onOpenForecast,
    required this.onOpenProjects,
    super.key,
  });

  final DirectorDashboard data;
  final VoidCallback onOpenForecast;
  final VoidCallback onOpenProjects;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final next = data.proximaSemanaTotal;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PaKpiRow([
        ('${data.tutoriasRealizadas}', 'Tutorías dadas'),
        (_pct(data.tasaAsistencia), 'Asistencia'),
        ('—', 'Satisfacción'),
      ]),
      // Tarjeta "Próxima semana"
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          child: NeuSurface(
            radius: 20,
            padding: const EdgeInsets.all(14),
            onTap: onOpenForecast,
            child: Row(children: [
              NeuSurface(
                radius: 16,
                shadows: Neu.raiseS,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.bar_chart_rounded, size: 26, color: p.c),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next == null
                            ? 'Próxima semana: sin pronóstico'
                            : 'Próxima semana: ~$next asistencias',
                        style: neuPoppins(size: 16, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next == null
                            ? 'No hay tutorías programadas para estimar · ver pronóstico'
                            : 'Según el modelo de asistencia · ver pronóstico',
                        style: neuBody(size: 13, color: Neu.muted, height: 1.3),
                      ),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 26, color: Neu.chevron),
            ]),
          ),
        ),
      ),
      const PaSection('Más información'),
      PaRowList([
        DirRow(
          icon: Icons.groups_outlined,
          title: 'Proyectos de aula',
          subtitle: 'Estado de los proyectos inscritos',
          onTap: onOpenProjects,
        ),
      ]),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  TUTORÍAS
// ═════════════════════════════════════════════════════════════════════════════

class DirTutoriasView extends StatefulWidget {
  const DirTutoriasView({required this.data, super.key});

  final DirectorDashboard data;

  @override
  State<DirTutoriasView> createState() => _DirTutoriasViewState();
}

class _DirTutoriasViewState extends State<DirTutoriasView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedCareer;
  int? _selectedSemester;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _normalize(String text) {
    const accented = 'áéíóúüñÁÉÍÓÚÜÑ';
    const plain = 'aeiouunAEIOUUN';
    var out = text.toLowerCase().trim();
    for (var i = 0; i < accented.length; i++) {
      out = out.replaceAll(accented[i], plain[i]);
    }
    return out;
  }

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _selectedCareer != null ||
      _selectedSemester != null;

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _query = '';
      _selectedCareer = null;
      _selectedSemester = null;
    });
  }

  Widget _buildSearchField(NeuPalette p) {
    return NeuSurface(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: neuBody(size: 14),
        decoration: InputDecoration(
          icon: Icon(Icons.search_rounded, size: 20, color: p.c),
          hintText: 'Buscar materia...',
          hintStyle: neuBody(size: 14, color: Neu.muted),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Neu.muted),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildCareerDropdown(NeuPalette p, List<String> careers) {
    return NeuSurface(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedCareer,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: p.c),
          hint: Text('Todas las carreras',
              overflow: TextOverflow.ellipsis,
              style: neuBody(size: 13, color: Neu.muted)),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('Todas las carreras',
                  overflow: TextOverflow.ellipsis,
                  style: neuBody(size: 13)),
            ),
            for (final c in careers)
              DropdownMenuItem<String?>(
                value: c,
                child: Text(c,
                    overflow: TextOverflow.ellipsis,
                    style: neuBody(size: 13)),
              ),
          ],
          onChanged: (val) => setState(() => _selectedCareer = val),
        ),
      ),
    );
  }

  Widget _buildSemesterDropdown(NeuPalette p) {
    return NeuSurface(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _selectedSemester,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: p.c),
          hint: Text('Semestre',
              overflow: TextOverflow.ellipsis,
              style: neuBody(size: 13, color: Neu.muted)),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text('Todos los semestres',
                  overflow: TextOverflow.ellipsis,
                  style: neuBody(size: 13)),
            ),
            for (var sem = 1; sem <= 10; sem++)
              DropdownMenuItem<int?>(
                value: sem,
                child: Text('Semestre $sem',
                    overflow: TextOverflow.ellipsis,
                    style: neuBody(size: 13)),
              ),
          ],
          onChanged: (val) => setState(() => _selectedSemester = val),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final allSubjects = widget.data.tutoriasPorMateria;

    final careers = <String>{
      ...careerCatalog,
      for (final s in allSubjects) ...s.carreras,
    }.toList();

    final normalizedQuery = _normalize(_query);
    final filtered = allSubjects.where((s) {
      final matchesQuery = normalizedQuery.isEmpty ||
          _normalize(s.materia).contains(normalizedQuery);
      final matchesCareer =
          _selectedCareer == null || s.carreras.contains(_selectedCareer);
      final matchesSemester =
          _selectedSemester == null || s.semestres.contains(_selectedSemester);
      return matchesQuery && matchesCareer && matchesSemester;
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 680;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isWide)
                  Row(
                    children: [
                      Expanded(flex: 4, child: _buildSearchField(p)),
                      const SizedBox(width: 10),
                      Expanded(flex: 3, child: _buildCareerDropdown(p, careers)),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: _buildSemesterDropdown(p)),
                    ],
                  )
                else ...[
                  _buildSearchField(p),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(flex: 3, child: _buildCareerDropdown(p, careers)),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: _buildSemesterDropdown(p)),
                    ],
                  ),
                ],
                if (_hasActiveFilters) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mostrando ${filtered.length} de ${allSubjects.length} materias',
                        style: neuBody(size: 12, color: Neu.muted),
                      ),
                      GestureDetector(
                        onTap: _clearFilters,
                        child: Text(
                          'Limpiar filtros',
                          style: neuPoppins(
                              size: 12, weight: FontWeight.w600, color: p.c),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
      PaRowList(
        [
          for (final s in filtered)
            DirRow(
              title: s.materia,
              subtitle:
                  '${s.tutoriasRealizadas} dadas · ${s.programadas} programadas · asistencia ${s.asistenciaTexto}',
              trailing: PaTag(dirStatusOf(s.tasaAsistencia).label,
                  tone: dirStatusOf(s.tasaAsistencia).tone),
            ),
        ],
        empty: _hasActiveFilters
            ? 'No se encontraron materias con los filtros seleccionados.'
            : 'Todavía no hay tutorías registradas por materia.',
      ),
      const PaSection('Asistencia por materia'),
      DirHBars(
        items: [
          for (final s in filtered)
            if (s.tasaAsistencia != null)
              DirHBar(
                  s.materia,
                  (s.tasaAsistencia! / 100).clamp(0.0, 1.0).toDouble(),
                  '${s.tasaAsistencia!.round()}%'),
        ],
        footer: 'Las materias con menos asistencia necesitan más apoyo.',
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CALIDAD
// ═════════════════════════════════════════════════════════════════════════════

class DirCalidadView extends StatelessWidget {
  const DirCalidadView({required this.data, super.key});

  final DirectorDashboard data;

  @override
  Widget build(BuildContext context) =>
      CalidadPanel(semanas: data.ultimasSemanas);
}

// ═════════════════════════════════════════════════════════════════════════════
//  PRONÓSTICO
// ═════════════════════════════════════════════════════════════════════════════

class DirForecastView extends StatelessWidget {
  const DirForecastView({
    required this.data,
    required this.onOpenAttendance,
    super.key,
  });

  final DirectorDashboard data;
  final VoidCallback onOpenAttendance;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final week = data.semanaPronosticada;
    final next = data.proximaSemanaTotal;
    final range = data.rangoProximaSemana;
    final trend = data.tendencia;
    final weeks = data.ultimasSemanas;
    final perSubject = data.pronosticoPorMateria;

    if (week == null || next == null || range == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PaInfo(
            data.modeloAsistenciaDisponible
                ? 'Todavía no hay pronósticos. No hay tutorías programadas compatibles con el modelo de asistencia.'
                : 'El modelo de asistencia no está disponible en este momento.',
            icon: Icons.info_outline_rounded),
        _attendanceEntry(),
      ]);
    }

    final (low, high) = range;
    final (trendText, trendTone) = switch (trend) {
      'sube' => ('Tendencia: sube', PaTone.ok),
      'baja' => ('Tendencia: baja', PaTone.warn),
      _ => ('Tendencia: estable', PaTone.neutral),
    };
    final weekLabel = _dm(week.semanaInicio);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PaInfo(
          'El modelo de asistencia estima cuántos estudiantes asistirán a las tutorías programadas. La próxima semana se verá así:'),
      PaCard(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(children: [
          Text('Asistencias estimadas · semana del $weekLabel',
              textAlign: TextAlign.center,
              style: neuBody(size: 14, color: Neu.muted)),
          const SizedBox(height: 6),
          Text('~$next',
              style: neuPoppins(
                  size: 46, weight: FontWeight.w700, color: p.c, height: 1.15)),
          const SizedBox(height: 10),
          Text('Rango de referencia: $low a $high',
              textAlign: TextAlign.center,
              style: neuBody(size: 14, color: Neu.muted)),
          if (trend != null) ...[
            const SizedBox(height: 12),
            PaTag(trendText, tone: trendTone),
          ],
        ]),
      ),
      const PaSection('Por materia · tutorías programadas'),
      DirBarChart(
        height: 150,
        showValues: true,
        labelLines: 3,
        bars: [
          for (final item in perSubject.take(6))
            DirBar(item.materia, item.total.toDouble()),
        ],
        caption: perSubject.length > 6
            ? 'Las 6 materias con más asistencias estimadas (de ${perSubject.length} con tutorías programadas).'
            : 'Asistencias estimadas en las tutorías programadas de cada materia.',
      ),
      _attendanceEntry(),
      PaCard(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Histórico y pronóstico', style: neuPoppins(size: 16)),
                const SizedBox(height: 12),
                _InnerChart(
                  bars: [
                    for (var i = 0; i < weeks.length; i++)
                      DirBar('S${i + 1}', weeks[i].total.toDouble()),
                    DirBar('P1', week.tutoriasEvaluadas.toDouble(),
                        light: true),
                  ],
                  caption:
                      'S = semanas pasadas · P = tutorías programadas, semana del $weekLabel (barra clara).',
                ),
              ]),
        ),
      ),
    ]);
  }

  Widget _attendanceEntry() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PaSection('Asistencia y estimación'),
          PaRowList([
            DirRow(
              icon: Icons.history_rounded,
              title: 'Asistencia y estimación',
              subtitle: 'Actividad de la app y estimación por materia',
              onTap: onOpenAttendance,
            ),
          ]),
        ],
      );
}

/// Gráfica sin tarjeta propia, para anidarla dentro de otra tarjeta con título.
class _InnerChart extends StatelessWidget {
  const _InnerChart({required this.bars, required this.caption});

  final List<DirBar> bars;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final light = Color.lerp(Colors.white, p.c, .55)!;
    final maximum = bars.fold<double>(
        1, (largest, bar) => bar.value > largest ? bar.value : largest);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 120,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final bar in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.5),
                child: LayoutBuilder(builder: (context, box) {
                  final h = (box.maxHeight * (bar.value / maximum))
                      .clamp(6.0, box.maxHeight)
                      .toDouble();
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: bar.light ? light : p.c,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        for (final bar in bars)
          Expanded(
            child: Text(bar.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: neuBody(size: 10, color: Neu.muted)),
          ),
      ]),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(caption, style: neuBody(size: 12, color: Neu.muted)),
      ),
    ]);
  }
}
