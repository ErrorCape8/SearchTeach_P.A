import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/director_dashboard_provider.dart';
import '../dashboard/director_widgets.dart';
import '../pa/pa_widgets.dart';
import 'calidad_director_provider.dart';
import 'servicio_tutorias_calidad_card.dart';

/// Contenido de la vista Calidad. Se reutiliza para la calidad general y para
/// Proyecto de aula (pasando un [filtro] con `tipo: 'PA'` y, opcionalmente,
/// una carrera).
///
/// Muestra: calificación general anónima, calificación por materia (solo
/// materias con tutorías calificadas), gráfico opcional de tutorías por
/// semana y los comentarios predeterminados más repetidos.
class CalidadPanel extends ConsumerWidget {
  const CalidadPanel({
    this.filtro = const CalidadFiltro(),
    this.titulo = 'Servicio de tutorías',
    this.semanas,
    super.key,
  });

  final CalidadFiltro filtro;
  final String titulo;

  /// Si se entrega, se dibuja "Tutorías por semana" tras las calificaciones.
  final List<WeeklyTutoringCount>? semanas;

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

    final frecuentes = summary?.comentariosMasRepetidos.take(6).toList() ??
        const <ComentarioFrecuenteItem>[];
    final maxVeces =
        frecuentes.isEmpty ? 1 : frecuentes.first.veces.clamp(1, 1 << 30);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      if (semanas != null) ...[
        const PaSection('Tutorías por semana'),
        DirBarChart(
          height: 130,
          bars: [
            for (var i = 0; i < semanas!.length; i++)
              DirBar('S${i + 1}', semanas![i].total.toDouble()),
          ],
        ),
      ],
      if (hayDatos) ...[
        const PaSection('Comentarios que más se repiten'),
        DirHBars(
          items: [
            for (final c in frecuentes)
              DirHBar(c.comentario, c.veces / maxVeces, '${c.veces}'),
          ],
          footer: frecuentes.isEmpty
              ? null
              : 'Mensajes predeterminados elegidos al calificar cada tutoría.',
        ),
      ],
    ]);
  }
}
