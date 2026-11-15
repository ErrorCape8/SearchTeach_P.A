import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../neu/neu.dart';
import '../role_theme.dart';

const kAuthBlue = Color(0xFF1E3FA8);
const kAuthNavy = Color(0xFF14146B);
const kAuthCrimson = Color(0xFFA9154F);
const kAuthInk = Color(0xFF1C1F24);

/// Logo transparente en blanco/celeste, pensado para el fondo azul.
const _kLogoLight = 'assets/images/logo_searchteach_light.png';

const _panelGradient = RadialGradient(
  center: Alignment(-0.6, -0.9),
  radius: 1.6,
  colors: [Color(0xFF3D63D1), kAuthNavy],
);

/// Marco común de Inicio de sesión, Registro y Recuperar contraseña.
///
/// * Pantalla ancha (PC, tablet) **o celular en horizontal**: panel azul de
///   marca a la izquierda (logo centrado) + formulario a la derecha.
///   El formulario hace scroll, así que se puede usar aunque la altura sea
///   muy corta (celular acostado).
/// * Celular en vertical: cabecera azul con el logo y, debajo, una hoja con
///   el formulario.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Línea inferior, por ejemplo "¿Sin cuenta? Regístrate aquí".
  final Widget? footer;

  /// Desde este ancho se usa el diseño de PC.
  static const splitMinWidth = 720.0;

  /// Ancho mínimo para usar el diseño de PC cuando el celular está en horizontal.
  static const landscapeMinWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Theme(
      data: withRoleAccent(
        theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(primary: kAuthBlue),
          scaffoldBackgroundColor: Neu.bg,
        ),
        kAuthBlue,
      ),
      child: Scaffold(
        backgroundColor: Neu.bg,
        body: LayoutBuilder(builder: (context, c) {
          final split = c.maxWidth >= splitMinWidth ||
              (landscape && c.maxWidth >= landscapeMinWidth);
          if (split) {
            // Celular acostado: poca altura → formulario más compacto.
            return _AuthMetrics(
              dense: c.maxHeight < 520,
              child: _SplitLayout(shell: this, width: c.maxWidth),
            );
          }
          return _AuthMetrics(
            dense: false,
            child: _StackedLayout(shell: this, height: c.maxHeight),
          );
        }),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Densidad (celular horizontal = más compacto)
// ═════════════════════════════════════════════════════════════════════════════

class _AuthMetrics extends InheritedWidget {
  const _AuthMetrics({required this.dense, required super.child});
  final bool dense;

  static bool denseOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AuthMetrics>()?.dense ??
      false;

  @override
  bool updateShouldNotify(_AuthMetrics old) => old.dense != dense;
}

// ═════════════════════════════════════════════════════════════════════════════
//  Bloque del formulario (título + subtítulo + contenido + pie)
// ═════════════════════════════════════════════════════════════════════════════

class _FormBlock extends StatelessWidget {
  const _FormBlock({required this.shell, required this.titleSize});
  final AuthShell shell;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final dense = _AuthMetrics.denseOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          shell.title,
          textAlign: TextAlign.center,
          style: neuPoppins(
            size: dense ? 24 : titleSize,
            weight: FontWeight.w700,
            color: Neu.text,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          shell.subtitle,
          textAlign: TextAlign.center,
          style: neuBody(size: 15, color: Neu.muted),
        ),
        SizedBox(height: dense ? 16 : 28),
        shell.child,
        if (shell.footer != null) ...[
          SizedBox(height: dense ? 12 : 22),
          Center(child: shell.footer),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PC / tablet / celular horizontal
// ═════════════════════════════════════════════════════════════════════════════

class _SplitLayout extends StatelessWidget {
  const _SplitLayout({required this.shell, required this.width});
  final AuthShell shell;
  final double width;

  @override
  Widget build(BuildContext context) {
    // En pantallas medianas (celular acostado) el formulario necesita más sitio.
    final wide = width >= 900;
    return Row(
      children: [
        Expanded(flex: wide ? 11 : 9, child: const _BrandPanel()),
        Expanded(
          flex: wide ? 9 : 11,
          child: SafeArea(
            left: false,
            child: LayoutBuilder(builder: (context, c) {
              final hPad = c.maxWidth < 420 ? 20.0 : 36.0;
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _FormBlock(shell: shell, titleSize: 32),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Panel azul con el logo centrado. Se adapta a la altura disponible:
/// alto → logo + frase + beneficios; medio → logo + frase; bajo → solo logo.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _panelGradient),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(right: -70, top: -110, child: _circle(300, .07)),
          Positioned.fill(
            child: SafeArea(
              right: false,
              child: LayoutBuilder(builder: (context, c) {
                final h = c.maxHeight;
                final w = c.maxWidth;
                final tier = h >= 640 ? 2 : (h >= 440 ? 1 : 0);
                final contentW = (w - 64).clamp(160.0, 440.0).toDouble();
                final double logoH = switch (tier) {
                  2 => (h * .27).clamp(150.0, 230.0).toDouble(),
                  1 => (h * .30).clamp(120.0, 200.0).toDouble(),
                  _ => (h * .50).clamp(90.0, 190.0).toDouble(),
                };
                final headlineSize = (w / 20).clamp(20.0, 34.0).toDouble();

                return Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    // Red de seguridad: si algo no cabe, se reduce todo.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: contentW,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              _kLogoLight,
                              height: logoH,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              semanticLabel: 'Logo de SearchTeach',
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.school_rounded,
                                size: logoH * .6,
                                color: Colors.white,
                              ),
                            ),
                            if (tier >= 1) ...[
                              SizedBox(height: tier == 2 ? 36 : 20),
                              Text(
                                'El conocimiento que buscas,\n'
                                'el profesor que necesitas',
                                textAlign: TextAlign.center,
                                style: neuPoppins(
                                  size: headlineSize,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.18,
                                  letterSpacing: -.4,
                                ),
                              ),
                            ],
                            if (tier == 2) ...[
                              const SizedBox(height: 36),
                              SizedBox(
                                width: contentW < 380 ? contentW : 380,
                                child: const Column(
                                  children: [
                                    _Feature(
                                      Icons.calendar_today_outlined,
                                      'Agenda tutorías',
                                      'Solicita, acepta o propone un nuevo horario.',
                                    ),
                                    _Feature(
                                      Icons.videocam_outlined,
                                      'Clases virtuales o presenciales',
                                      'Elige la modalidad que mejor te funcione.',
                                    ),
                                    _Feature(
                                      Icons.bar_chart_rounded,
                                      'Sigue tu progreso',
                                      'Asistencia y estadísticas en un solo lugar.',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: .30),
                    Colors.white.withValues(alpha: .10),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .18)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: neuBody(
                        size: 16, weight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: neuBody(
                      size: 14,
                      color: Colors.white.withValues(alpha: .82),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
//  Celular en vertical
// ═════════════════════════════════════════════════════════════════════════════

class _StackedLayout extends StatelessWidget {
  const _StackedLayout({required this.shell, required this.height});
  final AuthShell shell;
  final double height;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboardOpen = mq.viewInsets.bottom > 0;
    final double logoH =
        keyboardOpen ? 62.0 : (height * .15).clamp(88.0, 140.0).toDouble();
    final headerH = mq.padding.top + 18 + logoH + 22;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: _panelGradient),
        child: Column(
          children: [
            SizedBox(
              height: headerH,
              child: Padding(
                padding: EdgeInsets.only(top: mq.padding.top + 18, bottom: 22),
                child: Center(
                  child: Image.asset(
                    _kLogoLight,
                    height: logoH,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'Logo de SearchTeach',
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.school_rounded,
                      size: logoH * .6,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              constraints:
                  BoxConstraints(minHeight: math.max(0.0, height - headerH)),
              padding: EdgeInsets.fromLTRB(
                  22, 28, 22, 24 + (keyboardOpen ? 0 : mq.padding.bottom)),
              decoration: const BoxDecoration(
                color: Neu.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _FormBlock(shell: shell, titleSize: 26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Piezas de formulario (mismo estilo que la captura)
// ═════════════════════════════════════════════════════════════════════════════

/// Etiqueta sobre el campo ("DOCUMENTO", "CONTRASEÑA").
class AuthLabel extends StatelessWidget {
  const AuthLabel(this.text, {this.first = false, super.key});
  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final dense = _AuthMetrics.denseOf(context);
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : (dense ? 10 : 18), bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: neuBody(
            size: 13, weight: FontWeight.w500, color: Neu.muted, letterSpacing: .2),
      ),
    );
  }
}

/// Campo hundido y redondeado. Con [password] trae su propio botón de ojo.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    this.controller,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.password = false,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool password;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final _focus = FocusNode();
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dense = _AuthMetrics.denseOf(context);
    return NeuSunken(
      radius: 20,
      ring: _focus.hasFocus ? kAuthBlue : null,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.password && !_visible,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        autofillHints: widget.autofillHints,
        cursorColor: kAuthBlue,
        style: neuBody(size: 16, weight: FontWeight.w500, color: Neu.text),
        decoration: InputDecoration(
          isDense: true,
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
            size: 16,
            weight: FontWeight.w500,
            color: Neu.muted.withValues(alpha: .8),
          ),
          suffixIcon: widget.password
              ? IconButton(
                  tooltip: _visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
                  onPressed: () => setState(() => _visible = !_visible),
                  icon: Icon(
                    _visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Neu.muted,
                    size: 22,
                  ),
                )
              : null,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 20, vertical: dense ? 13 : 18),
        ),
      ),
    );
  }
}

/// Botón principal oscuro ("Iniciar sesión").
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton(
    this.label, {
    required this.onPressed,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dense = _AuthMetrics.denseOf(context);
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : .6,
      child: SizedBox(
        width: double.infinity,
        child: NeuSurface(
          radius: 20,
          padding: EdgeInsets.symmetric(vertical: dense ? 14 : 18, horizontal: 16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A3F47), kAuthInk],
          ),
          shadows: Neu.raiseS,
          onTap: enabled ? onPressed : null,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: neuPoppins(
                              size: 16, weight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario claro ("Atrás", "Reenviar otro código").
class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton(
    this.label, {
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dense = _AuthMetrics.denseOf(context);
    return Opacity(
      opacity: onPressed == null ? .6 : 1,
      child: SizedBox(
        width: double.infinity,
        child: NeuSurface(
          radius: 20,
          padding: EdgeInsets.symmetric(vertical: dense ? 13 : 16, horizontal: 16),
          shadows: Neu.raiseS,
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: kAuthBlue),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: neuPoppins(
                      size: 15, weight: FontWeight.w600, color: kAuthBlue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Casilla azul ("Mantener sesión iniciada").
class AuthCheck extends StatelessWidget {
  const AuthCheck({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        container: true,
        excludeSemantics: true,
        checked: value,
        label: label,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onChanged == null ? null : () => onChanged!(!value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: value ? kAuthBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: value ? kAuthBlue : Neu.navIdle,
                        width: 1.6,
                      ),
                    ),
                    child: value
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(label,
                        style: neuBody(size: 15, color: Neu.text)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Texto pulsable ("¿Olvidaste la contraseña?", "Regístrate aquí").
class AuthLink extends StatelessWidget {
  const AuthLink(
    this.text, {
    required this.onTap,
    this.color = kAuthBlue,
    this.weight = FontWeight.w700,
    super.key,
  });

  final String text;
  final VoidCallback onTap;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: neuBody(size: 14.5, weight: weight, color: color),
              ),
            ),
          ),
        ),
      );
}

/// "¿Sin cuenta? Regístrate aquí": texto gris + enlace azul.
class AuthFooterLine extends StatelessWidget {
  const AuthFooterLine(this.prefix, this.link, {required this.onTap, super.key});
  final String prefix;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(prefix, style: neuBody(size: 14.5, color: Neu.muted)),
          AuthLink(link, onTap: onTap),
        ],
      );
}

/// Mensaje de error sobre el formulario.
class AuthNotice extends StatelessWidget {
  const AuthNotice(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Semantics(
          liveRegion: true,
          child: NeuSunken(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 20, color: Neu.errFg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: neuBody(size: 14, color: Neu.errFg, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
