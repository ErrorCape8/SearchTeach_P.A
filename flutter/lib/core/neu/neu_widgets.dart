import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'neu_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  SUPERFICIES
// ═════════════════════════════════════════════════════════════════════════════

/// Caja **hundida** (`box-shadow: var(--sink)`): campos, íconos, barras, msg.
/// Dibuja las sombras internas porque `BoxShadow` solo sabe hacerlas hacia
/// afuera. [ring] reproduce el `0 0 0 2px var(--c)` del foco.
class NeuSunken extends StatelessWidget {
  const NeuSunken({
    required this.child,
    this.radius = 14,
    this.padding,
    this.color = Neu.bg,
    this.gradient,
    this.shadows = Neu.sink,
    this.ring,
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final Gradient? gradient;
  final List<NeuInsetShadow> shadows;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final content =
        padding == null ? child : Padding(padding: padding!, child: child);
    return CustomPaint(
      painter: _InsetPainter(
        radius: radius,
        color: color,
        gradient: gradient,
        shadows: shadows,
        ring: ring,
      ),
      child: content,
    );
  }
}

class _InsetPainter extends CustomPainter {
  const _InsetPainter({
    required this.radius,
    required this.color,
    required this.gradient,
    required this.shadows,
    required this.ring,
  });

  final double radius;
  final Color color;
  final Gradient? gradient;
  final List<NeuInsetShadow> shadows;
  final Color? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final fill = Paint();
    if (gradient != null) {
      fill.shader = gradient!.createShader(rect);
    } else {
      fill.color = color;
    }
    canvas.drawRRect(rrect, fill);

    canvas.save();
    canvas.clipRRect(rrect);
    for (final s in shadows) {
      // Sombra interna = lo que queda fuera de la caja desplazada, difuminado.
      final reach = s.blur * 2 + s.dx.abs() + s.dy.abs() + 8;
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(reach))
        ..addRRect(rrect.shift(Offset(s.dx, s.dy)));
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2),
      );
    }
    canvas.restore();

    if (ring != null) {
      canvas.drawRRect(
        rrect.inflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ring!,
      );
    }
  }

  @override
  bool shouldRepaint(_InsetPainter old) =>
      old.radius != radius ||
      old.color != color ||
      old.gradient != gradient ||
      old.ring != ring ||
      !listEquals(old.shadows, shadows);
}

/// Caja **elevada** (`--raise` / `--raise-s`). Si tiene [onTap] se hunde
/// mientras se presiona, como `:active{box-shadow:var(--sink)}`.
class NeuSurface extends StatefulWidget {
  const NeuSurface({
    required this.child,
    this.radius = 20,
    this.padding,
    this.onTap,
    this.shadows = Neu.raise,
    this.gradient,
    this.color = Neu.bg,
    this.sunken = false,
    this.clip = false,
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final List<BoxShadow> shadows;
  final Gradient? gradient;
  final Color color;

  /// Fuerza el estado hundido (chips activos, pestañas activas…).
  final bool sunken;

  /// Recorta el contenido a las esquinas (tabla dentro de tarjeta).
  final bool clip;

  @override
  State<NeuSurface> createState() => _NeuSurfaceState();
}

class _NeuSurfaceState extends State<NeuSurface> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    Widget content =
        w.padding == null ? w.child : Padding(padding: w.padding!, child: w.child);
    final pressed = w.sunken || (_down && w.onTap != null);

    Widget box;
    if (pressed) {
      box = NeuSunken(
        radius: w.radius,
        color: w.color,
        gradient: w.gradient,
        child: content,
      );
    } else {
      if (w.clip) {
        content = ClipRRect(
            borderRadius: BorderRadius.circular(w.radius), child: content);
      }
      box = DecoratedBox(
        decoration: BoxDecoration(
          color: w.gradient == null ? w.color : null,
          gradient: w.gradient,
          borderRadius: BorderRadius.circular(w.radius),
          boxShadow: w.shadows,
        ),
        child: content,
      );
    }

    if (w.onTap == null) return box;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: w.onTap,
        child: Semantics(button: true, child: box),
      ),
    );
  }
}

/// Caja de ícono hundida: `.ic` (48, r15), `.ic2` (40, r13), `.av2` (36, círculo).
class NeuIconBox extends StatelessWidget {
  const NeuIconBox(
    this.icon, {
    this.size = 40,
    this.radius = 13,
    this.iconSize = 22,
    this.color,
    super.key,
  });

  final IconData icon;
  final double size;
  final double radius;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? NeuPalette.of(context).c;
    return SizedBox(
      width: size,
      height: size,
      child: NeuSunken(
        radius: radius,
        child: Center(child: Icon(icon, size: iconSize, color: c)),
      ),
    );
  }
}

/// Botón circular elevado: `.ib` (42px) de la cabecera y `.av` (46px).
class NeuCircleButton extends StatelessWidget {
  const NeuCircleButton({
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.tooltip,
    this.badge,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  /// Contador rojo (`.nb`) sobre la campana.
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    Widget btn = SizedBox(
      width: size,
      height: size,
      child: NeuSurface(
        radius: size,
        shadows: Neu.raiseS,
        onTap: onTap,
        child: Center(child: Icon(icon, size: 24, color: p.c)),
      ),
    );
    if (badge != null && badge! > 0) {
      btn = Stack(clipBehavior: Clip.none, children: [
        btn,
        Positioned(
          top: -3,
          right: -3,
          child: Container(
            constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Neu.error, borderRadius: BorderRadius.circular(9)),
            child: Text('$badge',
                style: neuBody(
                    size: 10, weight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]);
    }
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CABECERA
// ═════════════════════════════════════════════════════════════════════════════

/// `.hd` en modo neumórfico: sin degradado ni círculos, sobre el fondo gris.
/// Título Poppins 19/700, subtítulo 13 gris, botón circular a la izquierda.
class NeuHeader extends StatelessWidget {
  const NeuHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          18, MediaQuery.paddingOf(context).top + 18, 18, 18),
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: neuPoppins(
                      size: 19,
                      weight: FontWeight.w700,
                      color: Neu.heading,
                      height: 1.2)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: neuBody(size: 13, color: Neu.muted)),
            ],
          ),
        ),
        for (final a in actions) ...[const SizedBox(width: 12), a],
      ]),
    );
  }
}

/// `.lgi`: logo del rol, 38 px de alto, en el extremo derecho de la cabecera.
/// Si el asset no está declarado simplemente no se muestra.
class NeuHeaderLogo extends StatelessWidget {
  const NeuHeaderLogo({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
        NeuPalette.of(context).logoAsset,
        height: 38,
        fit: BoxFit.contain,
        semanticLabel: 'Logo de SearchTeach',
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
//  BOTONES Y CHIPS
// ═════════════════════════════════════════════════════════════════════════════

enum NeuButtonKind { primary, alt, danger }

/// `.btn` (primario con degradado), `.btn.alt` y `.btn.red`; `small` = `.btn.sm`.
/// Con `onPressed: null` queda al 50 % y sin respuesta (`.btn[disabled]`).
class NeuButton extends StatelessWidget {
  const NeuButton(
    this.label, {
    required this.onPressed,
    this.kind = NeuButtonKind.primary,
    this.small = false,
    this.icon,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final NeuButtonKind kind;
  final bool small;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final primary = kind == NeuButtonKind.primary;
    final fg = switch (kind) {
      NeuButtonKind.primary => Colors.white,
      NeuButtonKind.alt => p.c,
      NeuButtonKind.danger => Neu.errFg,
    };
    final surface = NeuSurface(
      radius: small ? 12 : 15,
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
          : const EdgeInsets.all(14),
      gradient: primary ? p.gradient : null,
      shadows: Neu.raiseS,
      onTap: onPressed,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 16 : 20, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(label,
                textAlign: TextAlign.center,
                style: neuPoppins(size: small ? 12.5 : 14.5, color: fg)),
          ),
        ],
      ),
    );
    return Opacity(
      opacity: onPressed == null ? .5 : 1,
      child: expand ? SizedBox(width: double.infinity, child: surface) : surface,
    );
  }
}

/// `.chip`: elevado; activo (`.on`) = hundido, texto de acento en negrita.
class NeuChip extends StatelessWidget {
  const NeuChip(this.label,
      {this.selected = false, this.onTap, this.center = false, super.key});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Para chips que se reparten el ancho (calificaciones 1–5).
  final bool center;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final text = Text(
      label,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: neuBody(
        size: 13,
        weight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? p.c : Neu.text,
      ),
    );
    return NeuSurface(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      shadows: Neu.raiseS,
      sunken: selected,
      onTap: onTap,
      child: center ? SizedBox(width: double.infinity, child: text) : text,
    );
  }
}

/// Chips en varias líneas (`.chips` con `flex-wrap:wrap`).
class NeuChipWrap extends StatelessWidget {
  const NeuChipWrap(this.chips, {super.key});
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) => Wrap(
      spacing: 8, runSpacing: 10, children: chips);
}

/// Pestañas `.seg2`: contenedor hundido con la opción activa elevada.
class NeuSegmented extends StatelessWidget {
  const NeuSegmented({
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.icons,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final List<IconData>? icons;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    return NeuSunken(
      radius: 24,
      padding: const EdgeInsets.all(4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < labels.length; i++)
          NeuSurface(
            radius: 20,
            shadows: selected == i ? Neu.raiseS : const [],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            onTap: () => onSelect(i),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icons != null) ...[
                Icon(icons![i],
                    size: 16, color: selected == i ? p.c : Neu.muted),
                const SizedBox(width: 7),
              ],
              Text(labels[i],
                  style: neuBody(
                      size: 13,
                      weight: FontWeight.w700,
                      color: selected == i ? p.c : Neu.muted)),
            ]),
          ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CAMPOS
// ═════════════════════════════════════════════════════════════════════════════

/// `.in`: campo hundido (radio 14, 14×16). Al enfocar añade el aro de acento.
class NeuField extends StatefulWidget {
  const NeuField({
    this.controller,
    this.initialValue,
    this.hint,
    this.onChanged,
    this.keyboardType,
    this.obscure = false,
    this.enabled = true,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    super.key,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool enabled;
  final int? maxLength;
  final int? minLines;
  final int maxLines;

  @override
  State<NeuField> createState() => _NeuFieldState();
}

class _NeuFieldState extends State<NeuField> {
  final _focus = FocusNode();
  late final TextEditingController _ctrl;
  late final bool _ownsCtrl;

  @override
  void initState() {
    super.initState();
    _ownsCtrl = widget.controller == null;
    _ctrl = widget.controller ?? TextEditingController(text: widget.initialValue);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    if (_ownsCtrl) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    return NeuSunken(
      radius: 14,
      ring: _focus.hasFocus ? p.c : null,
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        enabled: widget.enabled,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        maxLength: widget.maxLength,
        minLines: widget.minLines,
        maxLines: widget.obscure ? 1 : widget.maxLines,
        onChanged: widget.onChanged,
        cursorColor: p.c,
        style: neuBody(
            size: 15,
            weight: FontWeight.w500,
            color: widget.enabled ? Neu.text : Neu.muted),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          filled: false,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          hintText: widget.hint,
          hintStyle: neuBody(
              size: 15,
              weight: FontWeight.w500,
              color: Neu.muted.withValues(alpha: .75)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

/// `select.in`: campo hundido con flecha a la derecha (padding-right 38).
class NeuDropdown<T> extends StatelessWidget {
  const NeuDropdown({
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.labelOf,
    super.key,
  });

  final List<T> items;
  final T? value;
  final String? hint;
  final ValueChanged<T?>? onChanged;
  final String Function(T)? labelOf;

  @override
  Widget build(BuildContext context) {
    final style = neuBody(size: 15, weight: FontWeight.w500);
    String label(T v) => labelOf != null ? labelOf!(v) : '$v';
    return NeuSunken(
      radius: 14,
      padding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: items.contains(value) ? value : null,
          hint: hint == null
              ? null
              : Text(hint!, style: style.copyWith(color: Neu.muted)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: Neu.muted),
          style: style,
          dropdownColor: Neu.bg,
          borderRadius: BorderRadius.circular(14),
          onChanged: onChanged,
          items: [
            for (final v in items)
              DropdownMenuItem<T>(
                  value: v,
                  child: Text(label(v), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// `.card.opt`: tarjeta de menú con ícono hundido, título Poppins 15/600,
/// subtítulo y flecha. Con [primary] (`.opt.pri`) se rellena con el degradado
/// del rol y texto blanco. En el CSS original esa variante queda con texto
/// blanco sobre gris (el selector `#app.neu .card` pisa el fondo); aquí se
/// resuelve como pretendía el diseño.
class NeuOptionCard extends StatelessWidget {
  const NeuOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    final fg = primary ? Colors.white : Neu.text;
    final sub = primary ? const Color(0xFFE5ECFF) : Neu.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: NeuSurface(
          radius: 20,
          padding: const EdgeInsets.all(16),
          gradient: primary ? p.gradient : null,
          shadows: primary ? Neu.raiseS : Neu.raise,
          onTap: onTap,
          child: Row(children: [
            primary
                ? Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(15)),
                    child: Icon(icon, size: 22, color: Colors.white),
                  )
                : NeuIconBox(icon, size: 48, radius: 15),
            const SizedBox(width: 14),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: neuPoppins(size: 15, color: fg)),
                Text(subtitle,
                    style: neuBody(size: 12.5, color: sub, height: 1.3)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 22, color: primary ? Colors.white : Neu.chevron),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  NAVEGACIÓN
// ═════════════════════════════════════════════════════════════════════════════

class NeuNavItem {
  const NeuNavItem(this.icon, this.label, {this.dot = false});
  final IconData icon;
  final String label;

  /// Punto rojo de pendientes (`.dot`).
  final bool dot;
}

/// `.nav` flotante: píldora elevada a 12 px de los bordes; la pestaña activa
/// queda hundida con el color del rol.
class NeuBottomBar extends StatelessWidget {
  const NeuBottomBar({
    required this.items,
    required this.index,
    required this.onSelect,
    super.key,
  });

  final List<NeuNavItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          12, 0, 12, 12 + MediaQuery.paddingOf(context).bottom),
      child: NeuSurface(
        radius: 26,
        padding: const EdgeInsets.all(7),
        child: Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: NeuSurface(
                radius: 19,
                shadows: const [],
                sunken: i == index,
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
                onTap: () => onSelect(i),
                child: Stack(clipBehavior: Clip.none, children: [
                  SizedBox(
                    width: double.infinity,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(items[i].icon,
                          size: 22, color: i == index ? p.c : Neu.navIdle),
                      const SizedBox(height: 2),
                      Text(items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: neuBody(
                              size: 10,
                              weight: FontWeight.w600,
                              color: i == index ? p.c : Neu.navIdle)),
                    ]),
                  ),
                  if (items[i].dot)
                    Positioned(
                      top: -1,
                      right: 14,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Neu.error, shape: BoxShape.circle),
                      ),
                    ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// `.fab`: botón flotante plano del color del rol (no lleva relieve neumórfico).
class NeuFab extends StatelessWidget {
  const NeuFab({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: p.c,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x48000000), offset: Offset(0, 10), blurRadius: 24),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 9),
          Text(label, style: neuPoppins(size: 14, color: Colors.white)),
        ]),
      ),
    );
  }
}
