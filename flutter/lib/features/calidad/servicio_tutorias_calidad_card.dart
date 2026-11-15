import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pa/pa_widgets.dart';
import 'calidad_director_provider.dart';

/// Tarjeta "Servicio de tutorías" para la vista Calidad.
/// Calcula y muestra la calificación general anónima a partir de las
/// estrellas (1-5) otorgadas por los estudiantes.
class ServicioTutoriasCalidadCard extends ConsumerWidget {
  const ServicioTutoriasCalidadCard({super.key});

  static const Color _starColor = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCalidad = ref.watch(calidadDirectorProvider);

    return NeuSurface(
      radius: 22,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Servicio de tutorías',
                  style: neuPoppins(size: 16.5, weight: FontWeight.w600),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Neu.bg.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_off_outlined,
                        size: 14, color: Neu.muted),
                    const SizedBox(width: 5),
                    Text(
                      'Anónimo',
                      style: neuBody(size: 11.5, color: Neu.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          asyncCalidad.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
            ),
            error: (_, __) => _EmptyCalidadState(),
            data: (summary) {
              if (summary.totalCalificaciones <= 0 ||
                  summary.promedioGeneral == null) {
                return const _EmptyCalidadState();
              }
              return _PopulatedCalidadContent(
                summary: summary,
                starColor: _starColor,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyCalidadState extends StatelessWidget {
  const _EmptyCalidadState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          'Aún no hay calificaciones registradas. Cuando existan, se mostrarán aquí sin identificar a quien califica.',
          textAlign: TextAlign.center,
          style: neuBody(size: 13.5, color: Neu.muted, height: 1.4),
        ),
      ),
    );
  }
}

class _PopulatedCalidadContent extends StatelessWidget {
  const _PopulatedCalidadContent({
    required this.summary,
    required this.starColor,
  });

  final CalidadGeneralSummary summary;
  final Color starColor;

  @override
  Widget build(BuildContext context) {
    final avg = summary.promedioGeneral!;
    final total = summary.totalCalificaciones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 520;
            final leftSummary = _GeneralScoreBlock(
              average: avg,
              totalCount: total,
              starColor: starColor,
            );
            final rightBars = _StarBreakdownBlock(
              distribution: summary.distribucionEstrellas,
              totalCount: total,
              starColor: starColor,
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 4, child: leftSummary),
                  const SizedBox(width: 24),
                  Expanded(flex: 6, child: rightBars),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftSummary,
                const SizedBox(height: 16),
                rightBars,
              ],
            );
          },
        ),
        if (summary.comentariosRecientes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Divider(color: Neu.muted.withValues(alpha: 0.16), height: 1),
          const SizedBox(height: 12),
          Text(
            'Comentarios recientes (anónimos)',
            style: neuPoppins(size: 13, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...summary.comentariosRecientes.take(3).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Neu.bg.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StarRow(
                              rating: item.estrellas.toDouble(),
                              size: 15,
                              color: starColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.materia,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: neuBody(
                                  size: 12,
                                  color: Neu.muted,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.comentario,
                          style: neuBody(size: 13, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _GeneralScoreBlock extends StatelessWidget {
  const _GeneralScoreBlock({
    required this.average,
    required this.totalCount,
    required this.starColor,
  });

  final double average;
  final int totalCount;
  final Color starColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              average.toStringAsFixed(1),
              style: neuPoppins(size: 38, weight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            Text(
              '/ 5.0',
              style: neuBody(size: 15, color: Neu.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _StarRow(rating: average, size: 22, color: starColor),
        const SizedBox(height: 8),
        Text(
          totalCount == 1
              ? 'Basado en 1 calificación estudiantil'
              : 'Basado en $totalCount calificaciones estudiantiles',
          style: neuBody(size: 12.5, color: Neu.muted),
        ),
      ],
    );
  }
}

class _StarBreakdownBlock extends StatelessWidget {
  const _StarBreakdownBlock({
    required this.distribution,
    required this.totalCount,
    required this.starColor,
  });

  final Map<int, int> distribution;
  final int totalCount;
  final Color starColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int star = 5; star >= 1; star--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Row(
                    children: [
                      Text(
                        '$star',
                        style: neuBody(
                            size: 12.5,
                            weight: FontWeight.w600,
                            color: Neu.muted),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.star_rounded, size: 14, color: starColor),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: totalCount > 0
                          ? (distribution[star] ?? 0) / totalCount
                          : 0,
                      backgroundColor: Neu.muted.withValues(alpha: 0.16),
                      valueColor: AlwaysStoppedAnimation<Color>(starColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${distribution[star] ?? 0}',
                    textAlign: TextAlign.end,
                    style: neuBody(size: 12, color: Neu.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.rating,
    required this.size,
    required this.color,
  });

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final threshold = index + 1;
        IconData icon;
        if (rating >= threshold - 0.25) {
          icon = Icons.star_rounded;
        } else if (rating >= threshold - 0.75) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}
