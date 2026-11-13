import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pa_store.dart';
import 'pa_widgets.dart';

/// Cronograma de tutorías colectivas visible para el estudiante (`cron`).
class PaCronogramaPage extends ConsumerStatefulWidget {
  const PaCronogramaPage({super.key});

  @override
  ConsumerState<PaCronogramaPage> createState() => _PaCronogramaPageState();
}

class _PaCronogramaPageState extends ConsumerState<PaCronogramaPage> {
  int _filtro = 0; // 0 = mi semestre, 1 = todo el programa

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(paUsuarioProvider).valueOrNull;
    final todas = ref.watch(paStoreProvider).colectivas;
    final programa = user?.programa ?? '';
    final delPrograma = programa.isEmpty
        ? todas
        : todas.where((c) => paNorm(c.carrera) == paNorm(programa)).toList();
    final base = delPrograma.isEmpty ? todas : delPrograma;
    final sem = user?.semestre;
    final lista = ((_filtro == 0 && sem != null)
            ? base.where((c) => c.semestre == sem).toList()
            : [...base])
        ..sort((a, b) =>
            a.semestre != b.semestre
                ? a.semestre.compareTo(b.semestre)
                : a.seccion.compareTo(b.seccion));

    return PaScaffold(
      title: 'Tutorías colectivas',
      subtitle: programa.isEmpty ? 'Cronograma de tu programa' : programa,
      children: [
        if (sem != null)
          PaSegmented(
            labels: ['Mi semestre ($sem)', 'Todo el programa'],
            selected: _filtro,
            onSelect: (i) => setState(() => _filtro = i),
          ),
        const PaInfo(
            'Aquí presentas el avance de tu proyecto de aula ante los docentes asignados.'),
        const SizedBox(height: 4),
        if (lista.isEmpty)
          const PaEmpty('No hay tutorías colectivas para tu semestre.')
        else
          // `.cgrid`: repeat(auto-fill, minmax(260px, 1fr)), gap 14.
          LayoutBuilder(builder: (context, box) {
            const gap = 14.0;
            final cols =
                math.max(1, ((box.maxWidth + gap) / (260 + gap)).floor());
            final w = (box.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final c in lista)
                SizedBox(width: w, child: _CronogramaCard(c)),
            ]);
          }),
      ],
    );
  }
}

/// `.col2`: bloque de fecha con degradado + datos de la tutoría.
class _CronogramaCard extends StatelessWidget {
  const _CronogramaCard(this.c);
  final PaColectiva c;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final partes = c.fecha.split(' ');
    final dia = partes.isNotEmpty ? partes[0] : '';
    final num = partes.length > 1 ? partes[1] : '';
    final mes = partes.length > 2 ? partes[2] : '';

    return NeuSurface(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // `.dblk`
          SizedBox(
            width: 58,
            child: NeuSurface(
              radius: 16,
              gradient: p.gradient,
              shadows: Neu.raiseS,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(dia.toUpperCase(),
                        style: neuPoppins(
                            size: 10.5,
                            weight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: .9))),
                    Text(num,
                        style: neuPoppins(
                            size: 22,
                            weight: FontWeight.w700,
                            color: Colors.white,
                            height: 1)),
                    Text(mes.toUpperCase(),
                        style: neuPoppins(
                            size: 10.5,
                            weight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: .9))),
                  ]),
            ),
          ),
          const SizedBox(width: 14),
          // `.cb`
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(c.materia,
                          style: neuBody(size: 16, weight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    PaTag(c.modalidad,
                        tone: c.virtual ? PaTone.neutral : PaTone.ok),
                  ]),
                  PaLine(
                      Icons.calendar_today_outlined,
                      Text(c.hora,
                          style: neuBody(size: 13, color: Neu.muted))),
                  PaLine(Icons.place_outlined,
                      Text(c.aulaLabel,
                          style: neuBody(size: 13, color: Neu.muted))),
                  PaLine(
                    Icons.person_outline_rounded,
                    Text.rich(TextSpan(
                      style: neuBody(size: 13, color: Neu.muted),
                      children: [
                        const TextSpan(text: 'Líder: '),
                        TextSpan(
                            text: c.lider.isEmpty ? 'Por asignar' : c.lider,
                            style: const TextStyle(
                                color: Neu.text, fontWeight: FontWeight.w700)),
                      ],
                    )),
                  ),
                  const SizedBox(height: 8),
                  if (c.apoyo.isEmpty)
                    Text('Sin docentes de apoyo',
                        style: neuBody(size: 13.3, color: Neu.muted))
                  else
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final a in c.apoyo) PaTag(a),
                    ]),
                ]),
          ),
        ]),
      ),
    );
  }
}
