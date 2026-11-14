import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/neu/neu.dart';
import '../../core/role_theme.dart';
import '../../core/widgets/role_toast.dart';

export '../../core/neu/neu.dart';

// Constantes que ya usaban otras pantallas: ahora apuntan a los tokens neu.
const paInk = Neu.text;
const paMuted = Neu.muted;
const paCanvas = Neu.bg;
const paLine = Neu.line;

/// Abre una vista conservando (o cambiando) el color de acento del rol.
Future<T?> paPush<T>(BuildContext context, Widget page, {Color? accent}) {
  final theme = Theme.of(context);
  final color = accent ?? theme.colorScheme.primary;
  return Navigator.of(context).push<T>(MaterialPageRoute(
    builder: (_) => Theme(
      data: withRoleAccent(
        theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(primary: color),
        ),
        color,
      ),
      child: page,
    ),
  ));
}

void paToast(BuildContext context, String message) =>
    RoleToast.showSnackBar(context, SnackBar(content: Text(message)));

// ═════════════════════════════════════════════════════════════════════════════
//  TAGS
// ═════════════════════════════════════════════════════════════════════════════

enum PaTone { neutral, ok, warn, error, quiet }

/// `.tag` (+ `.g`, `.o`, `.r`, `.sh`): 11px/700, radio 10, padding 4×9.
class PaTag extends StatelessWidget {
  const PaTag(this.text, {this.tone = PaTone.neutral, super.key});
  final String text;
  final PaTone tone;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final (bg, fg) = switch (tone) {
      PaTone.ok => (Neu.okBg, Neu.okFg),
      PaTone.warn => (Neu.warnBg, Neu.warnFg),
      PaTone.error => (Neu.errBg, Neu.errFg),
      PaTone.quiet => (Neu.quietBg, Neu.muted),
      PaTone.neutral => (p.s, p.c),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text,
          style: neuBody(size: 11, weight: FontWeight.w700, color: fg)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PANTALLA BASE
// ═════════════════════════════════════════════════════════════════════════════

/// Cabecera neumórfica (botón circular + título) y hoja de contenido sobre el
/// mismo fondo gris: `#app.neu .hd` + `#app.neu .sheet`.
class PaScaffold extends StatelessWidget {
  const PaScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions = const [],
    this.leading,
    super.key,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  /// Si se indica, reemplaza el botón «Volver» (p. ej. el avatar de perfil
  /// cuando la pantalla es una pestaña del panel y no una vista apilada).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Neu.bg,
        body: Column(children: [
          NeuHeader(
            title: title,
            subtitle: subtitle,
            leading: leading ??
                NeuCircleButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Volver',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
            actions: [...actions, const NeuHeaderLogo()],
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                      18, 8, 18, 32 + MediaQuery.paddingOf(context).bottom),
                  children: children,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  TARJETAS, KPIs, SECCIONES
// ═════════════════════════════════════════════════════════════════════════════

/// `.card`: elevada, radio 20, padding 16 y 12 de separación con la siguiente.
class PaCard extends StatelessWidget {
  const PaCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.clip = false,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool clip;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          child: NeuSurface(
            radius: 20,
            padding: padding,
            onTap: onTap,
            clip: clip,
            child: child,
          ),
        ),
      );
}

/// `.kpi`: radio 18, cifra Poppins 22/700 de acento y etiqueta 11.5 gris.
class PaKpi extends StatelessWidget {
  const PaKpi(this.value, this.label, {this.color, super.key});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => NeuSurface(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: SizedBox(
          width: double.infinity,
          child: Column(children: [
            Text(value,
                style: neuPoppins(
                    size: 22,
                    weight: FontWeight.w700,
                    color: color ?? NeuPalette.of(context).c)),
            Text(label,
                textAlign: TextAlign.center,
                style: neuBody(size: 11.5, color: Neu.muted)),
          ]),
        ),
      );
}

/// `.grid` de tres KPIs con 10 px de separación.
class PaKpiRow extends StatelessWidget {
  const PaKpiRow(this.items, {super.key});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: PaKpi(items[i].$1, items[i].$2)),
          ],
        ]),
      );
}

/// `.sec`: título Poppins 15/600 y acción de acento 13/700.
class PaSection extends StatelessWidget {
  const PaSection(this.title, {this.action, this.onAction, super.key});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: neuPoppins(size: 15))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: neuBody(
                      size: 13,
                      weight: FontWeight.w700,
                      color: NeuPalette.of(context).c)),
            ),
        ]),
      );
}

/// `.li`: ícono hundido 40×40, título 14.5/700, subtítulo 12 gris y, a la
/// derecha, un tag o la flecha `.ch`.
class PaRow extends StatelessWidget {
  const PaRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(children: [
        NeuIconBox(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: neuBody(
                    size: 14.5, weight: FontWeight.w700, height: 1.25)),
            if (subtitle != null)
              Text(subtitle!,
                  style: neuBody(size: 12, color: Neu.muted, height: 1.3)),
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        if (trailing == null && onTap != null)
          const Icon(Icons.chevron_right_rounded,
              size: 22, color: Neu.chevron),
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

/// Tarjeta con `padding: 4px 16px` y filas separadas por 1 px (`.li`).
/// Con [empty] y sin filas muestra el mensaje vacío dentro de la tarjeta.
class PaRowList extends StatelessWidget {
  const PaRowList(this.rows, {this.empty, super.key});
  final List<Widget> rows;
  final String? empty;

  @override
  Widget build(BuildContext context) => PaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: rows.isEmpty && empty != null
            ? PaEmpty(empty!)
            : Column(children: [
                for (var i = 0; i < rows.length; i++)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: i == rows.length - 1
                          ? null
                          : const Border(
                              bottom: BorderSide(color: Neu.line)),
                    ),
                    child: SizedBox(width: double.infinity, child: rows[i]),
                  ),
              ]),
      );
}

/// `.empty`.
class PaEmpty extends StatelessWidget {
  const PaEmpty(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 10),
        child: Center(
          child: Text(message,
              textAlign: TextAlign.center,
              style: neuBody(size: 14, color: Neu.muted)),
        ),
      );
}

/// `.msg`: caja hundida con el texto en el color del tono (inf/ok/err).
class PaInfo extends StatelessWidget {
  const PaInfo(this.message, {this.tone = PaTone.neutral, this.icon, super.key});
  final String message;
  final PaTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final color = switch (tone) {
      PaTone.ok => Neu.okFg,
      PaTone.error => Neu.errFg,
      _ => p.d,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        width: double.infinity,
        child: NeuSunken(
          radius: 14,
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
            ],
            Expanded(
                child: Text(message,
                    style: neuBody(size: 13.5, color: color, height: 1.3))),
          ]),
        ),
      ),
    );
  }
}

/// Fila de chips para filtros (`.chips`): scroll horizontal sin recortar la
/// sombra de los chips.
class PaSegmented extends StatelessWidget {
  const PaSegmented({
    required this.labels,
    required this.selected,
    required this.onSelect,
    super.key,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(top: 4, bottom: 14),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            NeuChip(labels[i],
                selected: selected == i, onTap: () => onSelect(i)),
          ],
        ]),
      );
}

/// `label` del formulario: 12/500 gris, mayúsculas, 12 px arriba y 6 abajo.
class PaFieldLabel extends StatelessWidget {
  const PaFieldLabel(this.text, {this.first = false, super.key});
  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 12, bottom: 6),
        child: Text(text.toUpperCase(),
            style: neuBody(
                size: 12, weight: FontWeight.w500, color: Neu.muted)),
      );
}

/// Calificación 1–5 como cinco chips que se reparten el ancho (rúbrica).
class PaScoreRow extends StatelessWidget {
  const PaScoreRow({required this.value, required this.onChanged, super.key});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          for (var v = 1; v <= 5; v++) ...[
            if (v > 1) const SizedBox(width: 6),
            Expanded(
              child: NeuChip('$v',
                  center: true,
                  selected: value == v,
                  onTap: () => onChanged(v)),
            ),
          ],
        ]),
      );
}

/// `.sr`: fila con ícono de acento (17 px) y texto 13 gris.
class PaLine extends StatelessWidget {
  const PaLine(this.icon, this.child, {super.key});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(children: [
          Icon(icon, size: 17, color: NeuPalette.of(context).c),
          const SizedBox(width: 9),
          Expanded(child: child),
        ]),
      );
}

/// Texto auxiliar `small` gris.
class PaHint extends StatelessWidget {
  const PaHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(text, style: neuBody(size: 13.3, color: Neu.muted, height: 1.3)),
      );
}
