import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pa_store.dart';
import 'pa_widgets.dart';

String _nombre(WidgetRef ref) =>
    ref.watch(paUsuarioProvider).valueOrNull?.nombre ?? '';

/// `dcol`: tutorías colectivas donde el docente es líder o apoyo.
class PaColectivasDocentePage extends ConsumerWidget {
  const PaColectivasDocentePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yo = _nombre(ref);
    final mias = ref
        .watch(paStoreProvider)
        .colectivas
        .where((c) =>
            paMismoNombre(c.lider, yo) || c.apoyo.any((a) => paMismoNombre(a, yo)))
        .toList();

    return PaScaffold(
      title: 'Tutorías colectivas',
      subtitle: 'Proyecto de aula asignadas a ti',
      children: [
        const PaInfo(
            'Aquí están todas las tutorías de proyecto de aula que coordinación te asignó, como líder o como apoyo.'),
        if (mias.isEmpty)
          const PaEmpty('Aún no tienes tutorías de proyecto de aula asignadas.')
        else ...[
          const PaSection('Tutorías colectivas'),
          PaRowList([
            for (final c in mias)
              PaRow(
                icon: Icons.groups_2_outlined,
                title: c.materia,
                subtitle:
                    '${c.cuando} · ${c.aulaLabel}\n${paMismoNombre(c.lider, yo) ? 'Tus docentes de apoyo: ${c.apoyo.isEmpty ? 'sin asignar' : c.apoyo.join(', ')}' : 'Líder: ${c.lider.isEmpty ? 'por asignar' : c.lider}'}',
                trailing: PaTag(paMismoNombre(c.lider, yo) ? 'Líder' : 'Apoyo',
                    tone: paMismoNombre(c.lider, yo)
                        ? PaTone.ok
                        : PaTone.neutral),
                onTap: () =>
                    paPush(context, PaColectivaDetallePage(colId: c.id)),
              ),
          ]),
        ],
      ],
    );
  }
}

/// `col`: el líder toma asistencia y consolida; el apoyo califica con rúbrica.
class PaColectivaDetallePage extends ConsumerWidget {
  const PaColectivaDetallePage({required this.colId, super.key});
  final int colId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yo = _nombre(ref);
    final st = ref.watch(paStoreProvider);
    final c = st.colectiva(colId);
    final lider = paMismoNombre(c.lider, yo);
    final at = st.asistencia[colId] ?? const <String, bool>{};
    final rubricas = st.rubricas.where((x) => x.colId == colId).toList();
    final enviado = st.reportes.any(
        (r) => r.colId == colId && paMismoNombre(r.por, yo) && r.fecha == 'hoy');

    return PaScaffold(
      title: c.materia,
      subtitle: 'Tutoría colectiva · ${c.cuando}',
      children: [
        PaCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(c.aulaLabel,
                      style: neuBody(size: 16, weight: FontWeight.w700))),
              PaTag(lider ? 'Docente líder' : 'Docente de apoyo',
                  tone: lider ? PaTone.ok : PaTone.neutral),
            ]),
            const SizedBox(height: 2),
            PaHint(lider
                ? 'Eres el líder · Docentes de apoyo: ${c.apoyo.isEmpty ? '—' : c.apoyo.join(', ')}'
                : 'Líder: ${c.lider} · Apoyo: ${c.apoyo.join(', ')}'),
          ]),
        ),
        if (lider) ...[
          const PaSection('Asistencia'),
          PaRowList([
            for (final a in paAlumnos)
              PaRow(
                icon: (at[a] ?? false)
                    ? Icons.check_rounded
                    : Icons.person_outline_rounded,
                title: a,
                trailing: PaTag((at[a] ?? false) ? 'Presente' : 'Sin marcar',
                    tone: (at[a] ?? false) ? PaTone.ok : PaTone.neutral),
                onTap: () => ref
                    .read(paStoreProvider.notifier)
                    .toggleAsistencia(colId, a),
              ),
          ]),
          const PaSection('Rúbricas de los docentes de apoyo'),
          PaRowList([
            for (final x in rubricas)
              PaRow(
                icon: Icons.description_outlined,
                title: x.estudiante,
                subtitle: 'Evaluó: ${x.por}',
                trailing: PaTag('${x.promedio.toStringAsFixed(1)} / 5'),
              ),
          ], empty: 'Aún no hay rúbricas.'),
          NeuButton(
            enviado
                ? 'Reporte enviado a coordinación'
                : 'Consolidar reporte',
            onPressed: enviado
                ? null
                : () => paPush(context, PaReporteConsolidadoPage(colId: colId)),
          ),
        ] else
          _RubricaForm(colId: colId, autor: yo),
      ],
    );
  }
}

/// `rubric()`: estudiante en chips, cuatro criterios 1–5 y observación.
class _RubricaForm extends ConsumerStatefulWidget {
  const _RubricaForm({required this.colId, required this.autor});
  final int colId;
  final String autor;

  @override
  ConsumerState<_RubricaForm> createState() => _RubricaFormState();
}

class _RubricaFormState extends ConsumerState<_RubricaForm> {
  String _estudiante = paAlumnos.first;
  List<int> _puntajes = List.filled(paCriterios.length, 0);
  final _obs = TextEditingController();

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  void _guardar() {
    if (_puntajes.any((v) => v == 0)) {
      paToast(context, 'Califica los ${paCriterios.length} criterios');
      return;
    }
    ref.read(paStoreProvider.notifier).guardarRubrica(PaRubrica(
          colId: widget.colId,
          por: widget.autor,
          estudiante: _estudiante,
          puntajes: List<int>.from(_puntajes),
          obs: _obs.text.trim(),
        ));
    setState(() {
      _puntajes = List.filled(paCriterios.length, 0);
      _obs.clear();
    });
    paToast(context, 'Rúbrica guardada');
  }

  @override
  Widget build(BuildContext context) {
    final propias = ref
        .watch(paStoreProvider)
        .rubricas
        .where((x) =>
            x.colId == widget.colId && paMismoNombre(x.por, widget.autor))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PaSection('Rúbrica de evaluación'),
      PaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PaFieldLabel('Estudiante', first: true),
          NeuChipWrap([
            for (final a in paAlumnos)
              NeuChip(a,
                  selected: _estudiante == a,
                  onTap: () => setState(() => _estudiante = a)),
          ]),
          for (var i = 0; i < paCriterios.length; i++) ...[
            PaFieldLabel(paCriterios[i]),
            PaScoreRow(
              value: _puntajes[i],
              onChanged: (v) => setState(() => _puntajes[i] = v),
            ),
          ],
          const PaFieldLabel('Observación'),
          NeuField(
              controller: _obs,
              hint: 'Retroalimentación para el estudiante'),
          const SizedBox(height: 14),
          NeuButton('Guardar rúbrica', onPressed: _guardar),
        ]),
      ),
      const PaSection('Tus rúbricas'),
      PaRowList([
        for (final x in propias)
          PaRow(
            icon: Icons.description_outlined,
            title: x.estudiante,
            subtitle: x.obs.isEmpty ? 'Sin observación' : x.obs,
            trailing: PaTag('${x.promedio.toStringAsFixed(1)} / 5'),
          ),
      ], empty: 'Aún no has evaluado a nadie.'),
    ]);
  }
}

/// `colrep`: vista previa del reporte que el líder envía a coordinación.
class PaReporteConsolidadoPage extends ConsumerWidget {
  const PaReporteConsolidadoPage({required this.colId, super.key});
  final int colId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yo = _nombre(ref);
    final st = ref.watch(paStoreProvider);
    final c = st.colectiva(colId);
    final at = st.asistencia[colId] ?? const <String, bool>{};
    final rubricas = st.rubricas.where((x) => x.colId == colId).toList();
    final presentes = paAlumnos.where((a) => at[a] ?? false).length;

    return PaScaffold(
      title: 'Reporte consolidado',
      subtitle: c.materia,
      children: [
        PaKpiRow([
          ('$presentes/${paAlumnos.length}', 'Asistentes'),
          ('${rubricas.length}', 'Rúbricas'),
          (
            rubricas.isEmpty
                ? '—'
                : paPromedio(rubricas.map((x) => x.promedio)).toStringAsFixed(1),
            'Promedio'
          ),
        ]),
        const PaSection('Por estudiante'),
        PaRowList([
          for (final a in paAlumnos)
            PaRow(
              icon: Icons.person_outline_rounded,
              title: a,
              subtitle:
                  '${rubricas.where((x) => x.estudiante == a).length} rúbrica(s)',
              trailing: PaTag((at[a] ?? false) ? 'Presente' : 'Ausente',
                  tone: (at[a] ?? false) ? PaTone.ok : PaTone.error),
            ),
        ]),
        const PaInfo(
            'Se envía a Coordinación en un solo reporte, con la asistencia y las rúbricas de los docentes de apoyo.'),
        NeuButton('Enviar a coordinación', onPressed: () {
          ref
              .read(paStoreProvider.notifier)
              .enviarReporte(colId, yo.isEmpty ? c.lider : yo);
          paToast(context, 'Reporte enviado a coordinación');
          Navigator.of(context).pop();
        }),
      ],
    );
  }
}
