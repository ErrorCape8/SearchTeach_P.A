import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pa_store.dart';
import 'pa_widgets.dart';

/// Cronograma de tutorías colectivas con su tutor líder, apoyos y aula.
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
    final sinLider = todas.where((c) => c.lider.isEmpty).length;

    return PaScaffold(
      title: 'Tutores líderes',
      subtitle: 'Cronograma de tutorías colectivas',
      children: [
        PaKpiRow([
          ('${todas.length - sinLider}/${todas.length}', 'Con líder'),
          ('$sinLider', 'Sin líder'),
          ('${carreras.length}', 'Programas'),
        ]),
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

class _Tabla extends StatelessWidget {
  const _Tabla(this.lista);
  final List<PaColectiva> lista;

  @override
  Widget build(BuildContext context) => PaCard(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            headingTextStyle: const TextStyle(
                color: paMuted, fontSize: 12, fontWeight: FontWeight.w800),
            columns: const [
              DataColumn(label: Text('SEM')),
              DataColumn(label: Text('SEC')),
              DataColumn(label: Text('MATERIA')),
              DataColumn(label: Text('FECHA Y HORA')),
              DataColumn(label: Text('AULA')),
              DataColumn(label: Text('LÍDER')),
              DataColumn(label: Text('APOYO')),
            ],
            rows: [
              for (final c in lista)
                DataRow(
                  onSelectChanged: (_) => _abrirAsignacion(context, c),
                  cells: [
                    DataCell(Text(c.semestreRomano)),
                    DataCell(Text('${c.seccion}')),
                    DataCell(Text(c.materia,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(c.cuando)),
                    DataCell(Text(c.aula)),
                    DataCell(c.lider.isEmpty
                        ? const PaTag('Sin líder', tone: PaTone.warn)
                        : Text(c.lider)),
                    DataCell(Text(c.apoyo.isEmpty ? '—' : c.apoyo.join(', '))),
                  ],
                ),
            ],
          ),
        ),
      );
}

class _Lista extends StatelessWidget {
  const _Lista(this.lista);
  final List<PaColectiva> lista;

  @override
  Widget build(BuildContext context) => PaRowList([
        for (final c in lista)
          PaRow(
            icon: Icons.groups_2_outlined,
            title: c.materia,
            subtitle:
                'Sem ${c.semestreRomano} · Sec ${c.seccion} · ${c.cuando}\n${c.lider.isEmpty ? 'Sin líder' : 'Líder: ${c.lider}'}${c.apoyo.isEmpty ? '' : '\nApoyo: ${c.apoyo.join(', ')}'}',
            trailing: c.lider.isEmpty
                ? const PaTag('Sin líder', tone: PaTone.warn)
                : PaTag(c.aulaLabel, tone: PaTone.ok),
            onTap: () => _abrirAsignacion(context, c),
          ),
      ]);
}

/// Asigna líder, docentes de apoyo y aula a una tutoría colectiva.
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
      subtitle:
          '${c.carrera} · Sem ${c.semestreRomano} · Sec ${c.seccion}',
      children: [
        PaCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PaFieldLabel('Tutor líder'),
            DropdownButtonFormField<String>(
              initialValue: _lider.isEmpty ? null : _lider,
              isExpanded: true,
              hint: const Text('Elige un docente'),
              decoration: paInput(),
              items: [
                for (final n in opciones)
                  DropdownMenuItem(value: n, child: Text(n)),
              ],
              onChanged: (v) => setState(() {
                _lider = v ?? '';
                _apoyo.remove(_lider);
              }),
            ),
            const PaFieldLabel('Docentes de apoyo del líder'),
            if (_lider.isEmpty)
              const Text('Primero elige al líder.',
                  style: TextStyle(color: paMuted, fontSize: 13))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final n in opciones.where((n) => n != _lider))
                  FilterChip(
                    label: Text(n),
                    selected: _apoyo.contains(n),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _apoyo.add(n);
                      } else {
                        _apoyo.remove(n);
                      }
                    }),
                  ),
              ]),
            const PaFieldLabel('Aula'),
            DropdownButtonFormField<String>(
              initialValue: _aula,
              isExpanded: true,
              decoration: paInput(),
              items: [
                for (final a in {...paAulas, _aula})
                  DropdownMenuItem(value: a, child: Text(a)),
              ],
              onChanged: (v) => setState(() => _aula = v ?? _aula),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref.read(paStoreProvider.notifier).asignar(
                      widget.colId,
                      _lider,
                      opciones.where(_apoyo.contains).toList(),
                      _aula);
                  paToast(context, 'Asignación guardada');
                  Navigator.of(context).pop();
                },
                child: const Text('Guardar asignación'),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

/// Reportes consolidados enviados por los docentes líderes.
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
        r.rubricas.isEmpty
            ? const PaEmpty('Sin rúbricas.')
            : PaRowList([
                for (final x in r.rubricas)
                  PaRow(
                    icon: Icons.description_outlined,
                    title: x.estudiante,
                    subtitle:
                        'Evaluó: ${x.por}${x.obs.isEmpty ? '' : ' · ${x.obs}'}',
                    trailing: PaTag('${x.promedio.toStringAsFixed(1)} / 5'),
                  ),
              ]),
        Text(
            'Líder: ${r.por} · Apoyo: ${c.apoyo.isEmpty ? '—' : c.apoyo.join(', ')}',
            style: const TextStyle(color: paMuted, fontSize: 12.5)),
      ],
    );
  }
}
