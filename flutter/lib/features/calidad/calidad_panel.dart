import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/director_widgets.dart';
import '../pa/pa_widgets.dart';
import 'calidad_director_provider.dart';
import 'servicio_tutorias_calidad_card.dart';

/// Contenido de la vista Calidad. Se reutiliza para la calidad general y para
/// Proyecto de aula (pasando un [filtro] con `tipo: 'PA'` y, opcionalmente,
/// una carrera).
///
/// Muestra calificaciones anónimas por materia y los comentarios
/// predeterminados más repetidos.
class CalidadPanel extends ConsumerWidget {
  const CalidadPanel({
    this.filtro = const CalidadFiltro(),
    this.titulo = 'Servicio de tutorías',
    this.analyticsFilters,
    super.key,
  });

  final CalidadFiltro filtro;
  final String titulo;
  final Widget? analyticsFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(calidadFiltradaProvider(filtro));
    final summary = async.asData?.value;
    final hayDatos = summary != null &&
        summary.totalCalificaciones > 0 &&
        summary.promedioGeneral != null;

    final materias = [
      if (summary != null)
        for (final m in summary.calificacionPorMateria)
          if (m.totalCalificaciones > 0) m,
    ]..sort((a, b) => b.promedioEstrellas.compareTo(a.promedioEstrellas));

    final frecuentes = summary?.comentariosMasRepetidos
            .where((item) => item.veces > 0)
            .take(6)
            .toList() ??
        const <ComentarioFrecuenteItem>[];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (analyticsFilters != null) analyticsFilters!,
      const PaInfo('Nunca se muestra quién califica.',
          icon: Icons.lock_outline_rounded),
      const SizedBox(height: 2),
      ServicioTutoriasCalidadCard(filtro: filtro, titulo: titulo),
      if (hayDatos) ...[
        const PaSection('Calificación por materia'),
        PaRowList(
          [
            for (final m in materias)
              DirRow(
                title: m.materia,
                subtitle: m.totalCalificaciones == 1
                    ? '1 calificación'
                    : '${m.totalCalificaciones} calificaciones',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded,
                      size: 18, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 3),
                  Text(m.promedioEstrellas.toStringAsFixed(1),
                      style: neuPoppins(size: 14.5, weight: FontWeight.w700)),
                ]),
              ),
          ],
          empty: 'Todavía no hay materias con tutorías calificadas.',
        ),
      ],
      if (hayDatos) ...[
        const PaSection('Comentarios que más se repiten'),
        _CommentDistributionCard(
          items: frecuentes,
          footer:
              'Distribución de los mensajes predeterminados elegidos al calificar.',
        ),
      ],
    ]);
  }
}

const _commentColors = [
  Color(0xFF6337BF),
  Color(0xFF2878C7),
  Color(0xFF1F9D8B),
  Color(0xFFE59A27),
  Color(0xFFD75B6A),
  Color(0xFF68758A),
];

class _CommentDistributionCard extends StatelessWidget {
  const _CommentDistributionCard({
    required this.items,
    required this.footer,
  });

  final List<ComentarioFrecuenteItem> items;
  final String footer;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const PaCard(
          child: PaEmpty('Todavía no hay comentarios repetidos para mostrar.'));
    }

    final total = items.fold<int>(0, (sum, item) => sum + item.veces);
    return PaCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          label: 'Gráfico circular con la distribución de comentarios frecuentes',
          child: Center(
            child: SizedBox(
              width: 168,
              height: 168,
              child: CustomPaint(
                painter: _CommentPiePainter(items: items, total: total),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _commentColors[index % _commentColors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  items[index].comentario,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: neuBody(size: 12.5, color: Neu.text),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${items[index].veces} · ${((items[index].veces / total) * 100).round()}%',
                style: neuPoppins(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: Neu.heading),
              ),
            ]),
          ),
        const SizedBox(height: 2),
        Text(footer, style: neuBody(size: 12, color: Neu.muted)),
      ]),
    );
  }
}

class _CommentPiePainter extends CustomPainter {
  const _CommentPiePainter({required this.items, required this.total});

  final List<ComentarioFrecuenteItem> items;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final bounds = Offset.zero & size;
    var startAngle = -math.pi / 2;
    for (var index = 0; index < items.length; index++) {
      final sweepAngle = 2 * math.pi * items[index].veces / total;
      canvas.drawArc(
        bounds,
        startAngle,
        sweepAngle,
        true,
        Paint()..color = _commentColors[index % _commentColors.length],
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _CommentPiePainter oldDelegate) =>
      oldDelegate.items != items || oldDelegate.total != total;
}
