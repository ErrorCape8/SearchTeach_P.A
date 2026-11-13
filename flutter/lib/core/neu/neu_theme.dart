import 'package:flutter/material.dart';

/// Tokens del estilo neumórfico de SearchTeach (luz arriba-izquierda).
///
/// Equivalencias con el CSS del prototipo (`#app.neu`):
///   --nb  → [bg]            --nd → [shadowDark]      --nl → [shadowLight]
///   --r   → [heading]       --ink → [text]           --mut → [muted]
///   --raise   → [raise]     --raise-s → [raiseS]     --sink → [sink]
abstract final class Neu {
  // ── Colores ──────────────────────────────────────────────────────────────
  static const bg = Color(0xFFE3E8F0);
  static const shadowDark = Color(0xFFB8C1D2);
  static const shadowLight = Color(0xFFFFFFFF);
  static const heading = Color(0xFF2A3142);
  static const text = Color(0xFF1B1E22);
  static const muted = Color(0xFF6C7380);
  static const line = Color(0xFFCDD5E3); // separadores de filas (.li)
  static const tableLine = Color(0xFFE8EBF1); // bordes de la tabla (.ctb)
  static const error = Color(0xFFE5484D);
  static const chevron = Color(0xFFB3BAC7);
  static const navIdle = Color(0xFF9AA2B1);

  // Colores de los tags / mensajes (.tag.g / .o / .r / .sh)
  static const okBg = Color(0xFFE3F6EA);
  static const okFg = Color(0xFF14683A);
  static const warnBg = Color(0xFFFFF1DD);
  static const warnFg = Color(0xFF9A5A00);
  static const errBg = Color(0xFFFDECEC);
  static const errFg = Color(0xFF8F2226);
  static const quietBg = Color(0xFFEEF1F6);

  // ── Sombras ──────────────────────────────────────────────────────────────
  /// `--raise`: 6px 6px 14px dark, -6px -6px 14px light (tarjetas, KPIs, nav).
  static const raise = <BoxShadow>[
    BoxShadow(color: shadowDark, offset: Offset(6, 6), blurRadius: 14),
    BoxShadow(color: shadowLight, offset: Offset(-6, -6), blurRadius: 14),
  ];

  /// `--raise-s`: 4px 4px 9px (botones, chips, avatares).
  static const raiseS = <BoxShadow>[
    BoxShadow(color: shadowDark, offset: Offset(4, 4), blurRadius: 9),
    BoxShadow(color: shadowLight, offset: Offset(-4, -4), blurRadius: 9),
  ];

  /// `--sink`: inset 4px 4px 9px dark, inset -4px -4px 9px light.
  /// Flutter no tiene sombras internas; las dibuja [NeuSunken].
  static const sink = <NeuInsetShadow>[
    NeuInsetShadow(shadowDark, 4, 4, 9),
    NeuInsetShadow(shadowLight, -4, -4, 9),
  ];
}

/// Una sombra interna (equivale a `inset dx dy blur color` en CSS).
@immutable
class NeuInsetShadow {
  const NeuInsetShadow(this.color, this.dx, this.dy, this.blur);
  final Color color;
  final double dx;
  final double dy;
  final double blur;

  @override
  bool operator ==(Object other) =>
      other is NeuInsetShadow &&
      other.color == color &&
      other.dx == dx &&
      other.dy == dy &&
      other.blur == blur;

  @override
  int get hashCode => Object.hash(color, dx, dy, blur);
}

/// Paleta del rol activo: `--c` (acento), `--d` (oscuro) y `--s` (suave).
/// El acento sale de `Theme.of(context).colorScheme.primary`, que ya cambia
/// por rol con `withRoleAccent`.
@immutable
class NeuPalette {
  const NeuPalette(this.c, this.d, this.s);
  final Color c;
  final Color d;
  final Color s;

  // Valores exactos de TH{} en el HTML (acento → oscuro, suave).
  static const _known = <int, (Color, Color)>{
    0x1E3FA8: (Color(0xFF14146B), Color(0xFFE6ECFB)), // acceso
    0x1769AA: (Color(0xFF164B83), Color(0xFFE7F1FC)), // estudiante
    0x16834A: (Color(0xFF18352A), Color(0xFFE6F4EA)), // docente
    0xEA580C: (Color(0xFFC2410C), Color(0xFFFFF1E6)), // administrador
    0xA9154F: (Color(0xFF86123F), Color(0xFFFCE7EF)), // coordinador
    0x6337BF: (Color(0xFF4B2A96), Color(0xFFEDE6FA)), // dirección
  };

  factory NeuPalette.of(BuildContext context) =>
      NeuPalette.fromAccent(Theme.of(context).colorScheme.primary);

  factory NeuPalette.fromAccent(Color c) {
    final known = _known[c.toARGB32() & 0xFFFFFF];
    return NeuPalette(
      c,
      known?.$1 ?? Color.lerp(c, Colors.black, .35)!,
      known?.$2 ?? Color.lerp(c, Colors.white, .88)!,
    );
  }

  /// Logo del rol (`LG[rol]` en el HTML). Declara `assets/images/` en el pubspec.
  String get logoAsset => switch (c.toARGB32() & 0xFFFFFF) {
        0x1769AA => 'assets/images/logo_est.png',
        0x16834A => 'assets/images/logo_doc.png',
        0xEA580C => 'assets/images/logo_adm.png',
        0xA9154F => 'assets/images/logo_coo.png',
        0x6337BF => 'assets/images/logo_dir.png',
        _ => 'assets/images/logo_login.png',
      };

  /// `color-mix(in srgb, var(--c) 82%, #fff)`.
  Color get light => Color.lerp(Colors.white, c, .82)!;

  /// `linear-gradient(145deg, light, c)` de `.btn` y `.dblk`.
  LinearGradient get gradient => LinearGradient(
        begin: const Alignment(-.57, -.82),
        end: const Alignment(.57, .82),
        colors: [light, c],
      );
}

/// Poppins para títulos, cifras y botones (`h1,h2,h3,.p` en el CSS).
/// Si la fuente no está declarada en el pubspec, Flutter usa la de sistema.
TextStyle neuPoppins({
  double size = 15,
  FontWeight weight = FontWeight.w600,
  Color color = Neu.text,
  double? height,
  double? letterSpacing,
}) =>
    TextStyle(
      fontFamily: 'Poppins',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

/// DM Sans para el texto corrido (`body` en el CSS).
TextStyle neuBody({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = Neu.text,
  double? height,
  double? letterSpacing,
}) =>
    TextStyle(
      fontFamily: 'DMSans',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
