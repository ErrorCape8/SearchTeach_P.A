import 'package:flutter/material.dart';

import 'pa_widgets.dart';

/// Tarjeta limpia de Proyecto de Aula para la vista "Proyectos de aula".
/// NO muestra el ID/cédula del tutor ("Tutor: 2000000017"), manteniendo el mismo
/// estilo visual limpio que las tarjetas de "Estado de cada materia".
class PaProyectoAulaCard extends StatelessWidget {
  const PaProyectoAulaCard({
    required this.titulo,
    required this.programa,
    required this.semestre,
    required this.estudiantesCount,
    required this.estado,
    this.onTap,
    super.key,
  });

  final String titulo;
  final String programa;
  final int? semestre;
  final int estudiantesCount;
  final String estado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final parts = <String>[
      if (programa.trim().isNotEmpty) programa.trim(),
      if (semestre != null && semestre! > 0) 'semestre $semestre',
      '$estudiantesCount ${estudiantesCount == 1 ? 'estudiante' : 'estudiantes'}',
    ];

    final normalizedEstado = estado.trim().isEmpty ? 'En curso' : estado.trim();
    final isCritico = normalizedEstado.toUpperCase().contains('RIESGO') ||
        normalizedEstado.toUpperCase().contains('CRITIC') ||
        normalizedEstado.toUpperCase().contains('CANCEL');

    final badgeBg =
        isCritico ? const Color(0xFFFDECEC) : const Color(0xFFE6F4EA);
    final badgeFg = isCritico ? Neu.errFg : Neu.okFg;

    return NeuSurface(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Row(
          children: [
            NeuSurface(
              radius: 16,
              shadows: Neu.raiseS,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.groups_rounded, size: 23, color: p.c),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo.trim().isEmpty ? 'Proyecto de aula' : titulo.trim(),
                    style: neuPoppins(size: 16, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    parts.join(' · '),
                    style: neuBody(size: 13, color: Neu.muted, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                normalizedEstado,
                style: neuBody(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: badgeFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
