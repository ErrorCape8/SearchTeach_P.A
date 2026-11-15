import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tutorias/coordinacion_tutorias_page.dart';
import 'pa_store.dart';
import 'pa_widgets.dart';

int _porSemestre(PaColectiva a, PaColectiva b) => a.semestre != b.semestre
    ? a.semestre.compareTo(b.semestre)
    : a.seccion.compareTo(b.seccion);

class PaLideresPage extends ConsumerStatefulWidget {
  const PaLideresPage({this.leading, super.key});

  final Widget? leading;

  @override
  ConsumerState<PaLideresPage> createState() => _PaLideresPageState();
}

class _PaLideresPageState extends ConsumerState<PaLideresPage> {
  int _vista = 0;

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(paStoreProvider).colectivas;
    final carreras = todas.map((c) => c.carrera).toSet().toList();
    final docenteMap = ref.watch(paDocenteMapProvider).valueOrNull ?? const {};

    return PaScaffold(
      title: 'Grupos apoyo proyecto de aula',
      subtitle: 'Cronograma y docentes asignados a proyectos de aula',
      leading: widget.leading,
      children: [
        PaSegmented(
          labels: const ['Tabla', 'Lista'],
          selected: _vista,
          onSelect: (i) => setState(() => _vista = i),
        ),
        PaInfo(_vista == 0
            ? 'Desliza la tabla para ver todo. Toca una fila para editar el líder y apoyos.'
            : 'Cada materia tiene un tutor líder y los docentes de apoyo asignados. Toca una fila para editar.'),
        for (final carrera in carreras) ...[
          PaSection(carrera),
          if (_vista == 0)
            _Tabla(todas.where((c) => c.carrera == carrera).toList(), docenteMap)
          else
            _Lista(todas.where((c) => c.carrera == carrera).toList(), docenteMap),
        ],
      ],
    );
  }
}

void _abrirAsignacion(BuildContext context, PaColectiva c) =>
    paPush(context, CoordinacionTutoriasPage(editingId: c.rawId.isNotEmpty ? c.rawId : '${c.id}'));

class _Tabla extends StatelessWidget {
  const _Tabla(this.lista, this.docentes);
  final List<PaColectiva> lista;
  final Map<String, String> docentes;

  static const _heads = [
    'SEM',
    'SEC',
    'DOCENTE',
    'DÍA · HORARIO',
    'AULA',
    'DOCENTES DE APOYO',
  ];
  static const _flex = [9.0, 7.0, 30.0, 22.0, 10.0, 22.0];

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final filas = [...lista]..sort(_porSemestre);
    final grupos = <int, List<PaColectiva>>{};
    for (final c in filas) {
      grupos.putIfAbsent(c.semestre, () => []).add(c);
    }

    return PaCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: LayoutBuilder(builder: (context, box) {
        final w = math.max(660.0, box.maxWidth);
        final cw = [for (final f in _flex) w * f / 100];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: w,
            child: Column(children: [
              Container(
                color: p.d,
                child: Row(children: [
                  for (var i = 0; i < _heads.length; i++)
                    SizedBox(
                      width: cw[i],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        child: Text(_heads[i],
                            textAlign: TextAlign.center,
                            style: neuBody(
                                size: 10.5,
                                weight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: .6)),
                      ),
                    ),
                ]),
              ),
              for (final g in grupos.entries)
                IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _celda(
                            cw[0],
                            Text(paRomanos[g.key.clamp(0, 10)],
                                style: neuPoppins(
                                    size: 12.5, weight: FontWeight.w700))),
                        SizedBox(
                          width: w - cw[0],
                          child: Column(children: [
                            for (final c in g.value) _fila(context, c, cw),
                          ]),
                        ),
                      ]),
                ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _fila(BuildContext context, PaColectiva c, List<double> cw) {
    final sub = neuBody(size: 10.5, color: Neu.muted);
    final partes = c.cuando.split(' · ');
    final dia = partes.first;
    final hora = partes.length > 1 ? partes.last : '';
    final liderNombre = docentes[c.lider] ?? c.lider;
    final apoyosNombres = c.apoyo.map((id) => docentes[id] ?? id).toList();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _abrirAsignacion(context, c),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _celda(cw[1], Text('${c.seccion}', style: _celdaTxt)),
          _celda(
            cw[2],
            Column(mainAxisSize: MainAxisSize.min, children: [
              if (liderNombre.isNotEmpty) ...[
                Text(liderNombre,
                    textAlign: TextAlign.center,
                    style: _celdaTxt.copyWith(fontWeight: FontWeight.w700)),
                Text('(LÍDER)', style: sub),
              ] else
                const PaTag('Sin líder', tone: PaTone.warn),
              Text(c.materia, textAlign: TextAlign.center, style: sub),
            ]),
          ),
          _celda(cw[3],
              Text('$dia\n$hora', textAlign: TextAlign.center, style: _celdaTxt)),
          _celda(cw[4], Text(c.aula, textAlign: TextAlign.center, style: _celdaTxt)),
          _celda(
              cw[5],
              Text(apoyosNombres.isEmpty ? 'N. A' : apoyosNombres.join('\n'),
                  textAlign: TextAlign.center, style: _celdaTxt)),
        ]),
      ),
    );
  }

  static final _celdaTxt = neuBody(size: 12.5, height: 1.35);

  static Widget _celda(double w, Widget child) => Container(
        width: w,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Neu.tableLine)),
        ),
        child: child,
      );
}

class _Lista extends StatelessWidget {
  const _Lista(this.lista, this.docentes);
  final List<PaColectiva> lista;
  final Map<String, String> docentes;

  @override
  Widget build(BuildContext context) {
    final filas = [...lista]..sort(_porSemestre);
    return PaRowList([
      for (final c in filas)
        PaRow(
          icon: Icons.groups_2_outlined,
          title: c.materia,
          subtitle:
              'Sem ${c.semestreRomano} · Sec ${c.seccion} · ${(docentes[c.lider] ?? c.lider).isNotEmpty ? 'Líder: ${docentes[c.lider] ?? c.lider} · ${c.apoyo.length} de apoyo' : 'Sin líder asignado'}',
          trailing: (docentes[c.lider] ?? c.lider).isNotEmpty
              ? const PaTag('Asignado', tone: PaTone.ok)
              : const PaTag('Pendiente', tone: PaTone.warn),
          onTap: () => _abrirAsignacion(context, c),
        ),
    ]);
  }
}

class PaAsignacionPage extends ConsumerStatefulWidget {
  const PaAsignacionPage({required this.colId, super.key});
  final int colId;

  @override
  ConsumerState<PaAsignacionPage> createState() => _PaAsignacionPageState();
}

class _PaAsignacionPageState extends ConsumerState<PaAsignacionPage> {
  late String _lider;
  late Set<String> _apoyo;
  late String _aula;

  @override
  void initState() {
    super.initState();
    final c = ref.read(paStoreProvider).colectiva(widget.colId);
    _lider = c.lider;
    _apoyo = c.apoyo.toSet();
    _aula = c.aula;
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(paStoreProvider).colectiva(widget.colId);
    final docentes = ref.watch(paDocentesProvider).valueOrNull ??
        ref.read(paStoreProvider).nombresDocentes;
    final opciones = {...docentes, if (_lider.isNotEmpty) _lider}.toList()
      ..sort();

    return PaScaffold(
      title: c.materia,
      subtitle: '${c.carrera} · Sem ${c.semestreRomano} · Sec ${c.seccion}',
      children: [
        PaCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PaFieldLabel('Tutor líder', first: true),
            NeuDropdown<String>(
              items: opciones,
              value: _lider.isEmpty ? null : _lider,
              hint: 'Elige un docente',
              onChanged: (v) => setState(() {
                _lider = v ?? '';
                _apoyo.remove(_lider);
              }),
            ),
            const PaFieldLabel('Docentes de apoyo del líder'),
            if (_lider.isEmpty)
              const PaHint('Primero elige al líder.')
            else
              NeuChipWrap([
                for (final n in opciones.where((n) => n != _lider))
                  NeuChip(n,
                      selected: _apoyo.contains(n),
                      onTap: () => setState(() {
                            if (!_apoyo.remove(n)) _apoyo.add(n);
                          })),
              ]),
            const PaFieldLabel('Aula'),
            NeuDropdown<String>(
              items: <String>{...paAulas, _aula}.toList(),
              value: _aula,
              onChanged: (v) => setState(() => _aula = v ?? _aula),
            ),
            const SizedBox(height: 14),
            NeuButton('Guardar asignación', onPressed: () {
              ref.read(paStoreProvider.notifier).asignar(widget.colId, _lider,
                  opciones.where(_apoyo.contains).toList(), _aula);
              paToast(context, 'Asignación guardada');
              Navigator.of(context).pop();
            }),
          ]),
        ),
      ],
    );
  }
}

class PaReportesPage extends ConsumerWidget {
  const PaReportesPage({this.leading, super.key});
  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(paStoreProvider);
    final reportes = st.reportesDeLider;
    return PaScaffold(
      title: 'Reportes',
      subtitle: 'Enviados por docentes líderes',
      leading: leading,
      children: [
        if (reportes.isEmpty)
          const PaEmpty('Aún no hay reportes.')
        else
          PaRowList([
            for (final r in reportes)
              PaRow(
                icon: Icons.inbox_outlined,
                title: st.colectiva(r.colId).materia,
                subtitle: 'Líder ${r.por} · ${r.fecha}',
                trailing: PaTag(r.visto ? 'Revisado' : 'Nuevo',
                    tone: r.visto ? PaTone.ok : PaTone.warn),
                onTap: () => paPush(context, PaReporteDetallePage(reporte: r)),
              ),
          ]),
      ],
    );
  }
}

class PaReporteDetallePage extends ConsumerStatefulWidget {
  const PaReporteDetallePage({required this.reporte, super.key});
  final PaReporte reporte;

  @override
  ConsumerState<PaReporteDetallePage> createState() =>
      _PaReporteDetallePageState();
}

class _PaReporteDetallePageState extends ConsumerState<PaReporteDetallePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(paStoreProvider.notifier).marcarVisto(widget.reporte);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reporte;
    final c = ref.read(paStoreProvider).colectiva(r.colId);
    final propias = r.rubricas.where((x) => paMismoNombre(x.por, r.por)).toList();
    final presentes = r.asistencia.values.where((v) => v).length;
    final promedios = propias.map((x) => x.promedio).toList();

    return PaScaffold(
      title: c.materia,
      subtitle: 'Reporte del docente líder · ${r.fecha}',
      children: [
        PaKpiRow([
          ('$presentes/${r.asistencia.length}', 'Asistentes'),
          ('${propias.length}', 'Rúbricas'),
          (
            promedios.isEmpty ? '—' : paPromedio(promedios).toStringAsFixed(1),
            'Promedio'
          ),
        ]),
        const PaSection('Asistencia'),
        PaRowList([
          for (final e in r.asistencia.entries)
            PaRow(
              icon: Icons.person_outline_rounded,
              title: e.key,
              subtitle: 'Estudiante',
              trailing: PaTag(e.value ? 'Presente' : 'Ausente',
                  tone: e.value ? PaTone.ok : PaTone.error),
            ),
        ]),
        const PaSection('Rúbricas del líder'),
        PaRowList([
          for (final x in propias)
            PaRow(
              icon: Icons.description_outlined,
              title: x.estudiante,
              subtitle: x.obs.isEmpty ? 'Evaluó: ${x.por}' : x.obs,
              trailing: PaTag('${x.promedio.toStringAsFixed(1)} / 5'),
            ),
        ], empty: 'Sin rúbricas.'),
        PaHint('Reporte enviado por el líder ${r.por}.'),
      ],
    );
  }
}

bool _mismaCarrera(String a, String b) {
  final x = paNorm(a), y = paNorm(b);
  if (x.isEmpty || y.isEmpty) return false;
  return x == y || x.contains(y) || y.contains(x);
}

class PaReporteLiderPage extends ConsumerWidget {
  const PaReporteLiderPage({required this.carrera, this.semestre, super.key});
  final String carrera;
  final int? semestre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(paStoreProvider);
    final propios = st.reportesDeLider.where((r) {
      final c = st.colectiva(r.colId);
      return (semestre == null || c.semestre == semestre) &&
          _mismaCarrera(c.carrera, carrera);
    }).toList();
    if (propios.isNotEmpty) return PaReporteDetallePage(reporte: propios.first);
    return PaScaffold(
      title: 'Reporte del líder',
      subtitle: carrera,
      children: const [PaEmpty('El docente líder aún no ha enviado su reporte.')],
    );
  }
}
