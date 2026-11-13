import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pa_store.dart';
import 'pa_widgets.dart';

/// Cronograma de tutorías colectivas visible para el estudiante.
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
    final lista = (_filtro == 0 && sem != null)
        ? base.where((c) => c.semestre == sem).toList()
        : base;

    return PaScaffold(
      title: 'Tutorías colectivas',
      subtitle: 'Cronograma de tu programa',
      children: [
        if (sem != null)
          PaSegmented(
            labels: ['Mi semestre ($sem)', 'Todo el programa'],
            selected: _filtro,
            onSelect: (i) => setState(() => _filtro = i),
          ),
        const PaInfo(
            'Aquí presentas el avance de tu proyecto de aula ante los docentes asignados.'),
        if (lista.isEmpty)
          const PaEmpty('No hay tutorías colectivas programadas.')
        else
          for (final c in lista) _CronogramaCard(c),
      ],
    );
  }
}

class _CronogramaCard extends StatelessWidget {
  const _CronogramaCard(this.c);
  final PaColectiva c;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final partes = c.fecha.split(' ');
    final dia = partes.isNotEmpty ? partes[0] : '';
    final num = partes.length > 1 ? partes[1] : '';
    final mes = partes.length > 2 ? partes[2] : '';
    return PaCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(dia.toUpperCase(),
                style: TextStyle(
                    color: primary, fontSize: 11, fontWeight: FontWeight.w800)),
            Text(num,
                style: TextStyle(
                    color: primary, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(mes,
                style: const TextStyle(color: paMuted, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.materia,
                style: const TextStyle(
                    color: paInk, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(
                '${c.carrera} · Sem ${c.semestreRomano} · Sec ${c.seccion}',
                style: const TextStyle(color: paMuted, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              PaTag(c.hora),
              PaTag(c.aulaLabel, tone: c.virtual ? PaTone.warn : PaTone.ok),
            ]),
            if (c.apoyo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final a in c.apoyo) PaTag(a),
              ]),
            ],
            const SizedBox(height: 8),
            Text(
                c.lider.isEmpty
                    ? 'Tutor líder por asignar'
                    : 'Tutor líder: ${c.lider}',
                style: const TextStyle(color: paMuted, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}
