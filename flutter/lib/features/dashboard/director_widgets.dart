import 'package:flutter/material.dart';

import '../pa/pa_widgets.dart';
import 'director_dashboard_provider.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  ESTADO DE CADA MATERIA (Bien · Atención · Crítico)
// ═════════════════════════════════════════════════════════════════════════════

enum DirStatus { bien, atencion, critico, sinDatos }

/// Umbrales de asistencia: < 60 % crítico, < 75 % atención, resto bien.
DirStatus dirStatusOf(double? attendance) {
  if (attendance == null) return DirStatus.sinDatos;
  if (attendance < 60) return DirStatus.critico;
  if (attendance < 75) return DirStatus.atencion;
  return DirStatus.bien;
}

extension DirStatusX on DirStatus {
  String get label => switch (this) {
        DirStatus.bien => 'Bien',
        DirStatus.atencion => 'Atención',
        DirStatus.critico => 'Crítico',
        DirStatus.sinDatos => 'Sin datos',
      };

  PaTone get tone => switch (this) {
        DirStatus.bien => PaTone.ok,
        DirStatus.atencion => PaTone.warn,
        DirStatus.critico => PaTone.error,
        DirStatus.sinDatos => PaTone.quiet,
      };

  Color get color => switch (this) {
        DirStatus.bien => Neu.okFg,
        DirStatus.atencion => Neu.warnFg,
        DirStatus.critico => Neu.errFg,
        DirStatus.sinDatos => Neu.muted,
      };
}

// ═════════════════════════════════════════════════════════════════════════════
//  DATOS DERIVADOS DEL DASHBOARD (sin inventar nada: todo sale del backend)
// ═════════════════════════════════════════════════════════════════════════════

/// Tutorías previstas para la próxima semana en una materia.
class DirSubjectForecast {
  const DirSubjectForecast(this.materia, this.total);
  final String materia;
  final int total;
}

extension DirectorDashboardX on DirectorDashboard {
  /// Pronóstico de la próxima semana por materia (de mayor a menor).
  List<DirSubjectForecast> get pronosticoPorMateria {
    final list = <DirSubjectForecast>[
      for (final s in tutoriasPorMateria)
        if (s.pronostico != null && s.pronostico!.prediccionesSemanales.isNotEmpty)
          DirSubjectForecast(
              s.materia, s.pronostico!.prediccionesSemanales.first.total),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  /// Suma del pronóstico de todas las materias; `null` si no hay pronóstico.
  int? get proximaSemanaTotal {
    final list = pronosticoPorMateria;
    if (list.isEmpty) return null;
    return list.fold<int>(0, (sum, item) => sum + item.total);
  }

  /// Últimas 10 semanas, de la más antigua a la más reciente.
  List<WeeklyTutoringCount> get ultimasSemanas {
    final all = historialSemanal;
    return all.length > 10 ? all.sublist(all.length - 10) : all;
  }

  /// `sube`, `baja` o `estable` frente a la última semana registrada.
  String? get tendencia {
    final next = proximaSemanaTotal;
    final weeks = ultimasSemanas;
    if (next == null || weeks.isEmpty) return null;
    final last = weeks.last.total;
    if (last == 0) return next > 0 ? 'sube' : 'estable';
    final change = (next - last) / last;
    if (change > .03) return 'sube';
    if (change < -.03) return 'baja';
    return 'estable';
  }

  int countStatus(DirStatus status) => tutoriasPorMateria
      .where((s) => dirStatusOf(s.tasaAsistencia) == status)
      .length;
}

extension SubjectTutoringSummaryX on SubjectTutoringSummary {
  int get programadas {
    final value = totalTutorias - tutoriasRealizadas;
    return value < 0 ? 0 : value;
  }

  String get asistenciaTexto =>
      tasaAsistencia == null ? 'sin datos' : '${tasaAsistencia!.round()}%';
}

// ═════════════════════════════════════════════════════════════════════════════
//  GRÁFICO DE BARRAS VERTICALES (`.bars`)
// ═════════════════════════════════════════════════════════════════════════════

class DirBar {
  const DirBar(this.label, this.value, {this.light = false});
  final String label;
  final double value;

  /// Barra clara = pronóstico.
  final bool light;
}

/// Tarjeta elevada con barras moradas redondeadas y etiqueta debajo de cada
/// una, igual que "Tutorías por semana" e "Histórico y pronóstico".
class DirBarChart extends StatelessWidget {
  const DirBarChart({
    required this.bars,
    this.height = 150,
    this.showValues = false,
    this.caption,
    this.labelLines = 1,
    super.key,
  });

  final List<DirBar> bars;
  final double height;
  final bool showValues;
  final String? caption;
  final int labelLines;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final light = Color.lerp(Colors.white, p.c, .55)!;
    final maximum = bars.fold<double>(
        1, (largest, bar) => bar.value > largest ? bar.value : largest);

    return PaCard(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (bars.isEmpty)
          const PaEmpty('Todavía no hay datos para mostrar.')
        else ...[
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bar in bars)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.5),
                      child: LayoutBuilder(builder: (context, box) {
                        final reserved = showValues ? 22.0 : 0.0;
                        final usable = box.maxHeight - reserved;
                        final h = (usable * (bar.value / maximum))
                            .clamp(6.0, usable)
                            .toDouble();
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showValues)
                                SizedBox(
                                  height: reserved,
                                  child: Center(
                                    child: Text(
                                      bar.value.round().toString(),
                                      style: neuPoppins(
                                          size: 12.5,
                                          weight: FontWeight.w700,
                                          color: p.c),
                                    ),
                                  ),
                                ),
                              Container(
                                height: h,
                                decoration: BoxDecoration(
                                  color: bar.light ? light : p.c,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            for (final bar in bars)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Text(
                    bar.label,
                    textAlign: TextAlign.center,
                    maxLines: labelLines,
                    overflow: TextOverflow.ellipsis,
                    style: neuBody(size: 10, color: Neu.muted, height: 1.2),
                  ),
                ),
              ),
          ]),
        ],
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(caption!, style: neuBody(size: 12, color: Neu.muted)),
        ],
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  BARRAS HORIZONTALES CON RIEL HUNDIDO (`.bar`)
// ═════════════════════════════════════════════════════════════════════════════

class DirHBar {
  const DirHBar(this.label, this.ratio, this.valueText);
  final String label;

  /// 0 a 1.
  final double ratio;
  final String valueText;
}

class DirHBars extends StatelessWidget {
  const DirHBars({required this.items, this.footer, super.key});

  final List<DirHBar> items;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    return PaCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (items.isEmpty)
          const PaEmpty('Todavía no hay datos para mostrar.')
        else
          LayoutBuilder(builder: (context, box) {
            final labelWidth =
                (box.maxWidth * .3).clamp(86.0, 124.0).toDouble();
            return Column(children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    SizedBox(
                      width: labelWidth,
                      child: Text(item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: neuBody(size: 13.5)),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 10,
                        child: NeuSunken(
                          radius: 6,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: item.ratio.clamp(0.0, 1.0).toDouble(),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: p.c,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 46,
                      child: Text(item.valueText,
                          textAlign: TextAlign.end,
                          style: neuBody(size: 13.5, weight: FontWeight.w700)),
                    ),
                  ]),
                ),
            ]);
          }),
        if (footer != null) ...[
          const SizedBox(height: 6),
          Text(footer!, style: neuBody(size: 13, color: Neu.muted)),
        ],
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  FILA DE MATERIA (`.li` con `.ic` de 46 px)
// ═════════════════════════════════════════════════════════════════════════════

class DirRow extends StatelessWidget {
  const DirRow({
    required this.title,
    required this.subtitle,
    this.icon = Icons.book_outlined,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        NeuIconBox(icon, size: 46, radius: 15, iconSize: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: neuPoppins(size: 15.5, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: neuBody(size: 12.5, color: Neu.muted, height: 1.3)),
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        if (trailing == null && onTap != null)
          const Icon(Icons.chevron_right_rounded,
              size: 24, color: Neu.chevron),
      ]),
    );
    if (onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
          behavior: HitTestBehavior.opaque, onTap: onTap, child: row),
    );
  }
}

/// Estado de carga / error con el mismo aspecto neumórfico.
class DirMessage extends StatelessWidget {
  const DirMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            NeuIconBox(icon, size: 64, radius: 22, iconSize: 30, color: p.c),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: neuPoppins(size: 17, color: Neu.heading)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: neuBody(size: 13.5, color: Neu.muted, height: 1.35)),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              NeuButton(actionLabel!,
                  onPressed: onAction, expand: false, small: true),
            ],
          ]),
        ),
      ),
    );
  }
}
