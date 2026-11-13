import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pa_store.dart';
import 'pa_widgets.dart';

int _porSemestre(PaColectiva a, PaColectiva b) => a.semestre != b.semestre
    ? a.semestre.compareTo(b.semestre)
    : a.seccion.compareTo(b.seccion);

/// `clid`: cronograma de tutorías colectivas con su líder, apoyos y aula.
class PaLideresPage extends ConsumerStatefulWidget {
  const PaLideresPage({super.key});

  @override
  ConsumerState<PaLideresPage> createState() => _PaLideresPageState();
}

class _PaLideresPageState extends ConsumerState<PaLideresPage> {
  int _vista = 0; // 0 = tabla, 1 = lista

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(paStoreProvider).colectivas;
    final carreras = todas.map((c) => c.carrera).toSet().toList();

    return PaScaffold(
      title: 'Tutores líderes',
      subtitle: 'Cronograma de tutorías colectivas',
      children: [
        PaSegmented(
          labels: const ['Tabla', 'Lista'],
          selected: _vista,
          onSelect: (i) => setState(() => _vista = i),
        ),
        PaInfo(_vista == 0
            ? 'Desliza la tabla para ver todo. Toca una fila para asignar líder, apoyos y aula.'
            : 'Cada materia tiene un tutor líder y los docentes de apoyo que él coordina.'),
        for (final carrera in carreras) ...[
          PaSection(carrera),
          if (_vista == 0)
            _Tabla(todas.where((c) => c.carrera == carrera).toList())
          else
            _Lista(todas.where((c) => c.carrera == carrera).toList()),
        ],
      ],
    );
  }
}

void _abrirAsignacion(BuildContext context, PaColectiva c) =>
    paPush(context, PaAsignacionPage(colId: c.id));

/// `.ctb`: cabecera con el color oscuro del rol, celdas blancas centradas y
/// la columna SEM combinada por semestre (`rowspan`). Ancho mínimo 660 px con
/// desplazamiento horizontal.
class _Tabla extends StatelessWidget {
  const _Tabla(this.lista);
  final List<PaColectiva> lista;

  static const _heads = [
    'SEM',
    'SEC',
    'DOCENTE',
    'DÍA · HORARIO',
    'AULA',
    'DOCENTES DE APOYO',
  ];
  static const _flex = [9.0, 7.0, 30.0, 22.0, 10.0, 22.0]; // suma 100

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
              // thead
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
              // tbody
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _abrirAsignacion(context, c),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _celda(cw[1], Text('${c.seccion}', style: _celdaTxt)),
          _celda(
            cw[2],
            Column(mainAxisSize: MainAxisSize.min, children: [
              if (c.lider.isNotEmpty) ...[
                Text(c.lider,
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
              Text(c.apoyo.isEmpty ? 'N. A' : c.apoyo.join('\n'),
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

/// `cList`: una fila por materia con tag Asignado / Pendiente.
class _Lista extends StatelessWidget {
  const _Lista(this.lista);
  final List<PaColectiva> lista;

  @override
  Widget build(BuildContext context) {
    final filas = [...lista]..sort(_porSemestre);
    return PaRowList([
      for (final c in filas)
        PaRow(
          icon: Icons.groups_2_outlined,
          title: c.materia,
          subtitle:
              'Sem ${c.semestreRomano} · Sec ${c.seccion} · ${c.lider.isNotEmpty ? 'Líder: ${c.lider} · ${c.apoyo.length} de apoyo' : 'Sin líder asignado'}',
          trailing: c.lider.isNotEmpty
              ? const PaTag('Asignado', tone: PaTone.ok)
              : const PaTag('Pendiente', tone: PaTone.warn),
          onTap: () => _abrirAsignacion(context, c),
        ),
    ]);
  }
}

/// `clid1`: asigna líder, docentes de apoyo y aula a una tutoría colectiva.
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

/// `crep`: reportes consolidados enviados por los docentes líderes.
class PaReportesPage extends ConsumerWidget {
  const PaReportesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(paStoreProvider);
    return PaScaffold(
      title: 'Reportes',
      subtitle: 'Enviados por docentes líderes',
      children: [
        if (st.reportes.isEmpty)
          const PaEmpty('Aún no hay reportes.')
        else
          PaRowList([
            for (final r in st.reportes)
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

/// `crepd`.
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
    // Al abrir el detalle el reporte queda marcado como revisado.
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
    final presentes = r.asistencia.values.where((v) => v).length;
    final promedios = r.rubricas.map((x) => x.promedio).toList();

    return PaScaffold(
      title: c.materia,
      subtitle: 'Reporte consolidado · ${r.fecha}',
      children: [
        PaKpiRow([
          ('$presentes/${r.asistencia.length}', 'Asistentes'),
          ('${r.rubricas.length}', 'Rúbricas'),
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
        const PaSection('Rúbricas de apoyo'),
        PaRowList([
          for (final x in r.rubricas)
            PaRow(
              icon: Icons.description_outlined,
              title: x.estudiante,
              subtitle: 'Evaluó: ${x.por}${x.obs.isEmpty ? '' : ' · ${x.obs}'}',
              trailing: PaTag('${x.promedio.toStringAsFixed(1)} / 5'),
            ),
        ], empty: 'Sin rúbricas.'),
        PaHint(
            'Líder: ${r.por} · Apoyo: ${c.apoyo.isEmpty ? '—' : c.apoyo.join(', ')}'),
      ],
    );
  }
}
