import 'package:flutter/material.dart';

/// Shared SearchTeach mark used by every Flutter platform.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.accentColor = const Color(0xFF1769AA),
  });

  final double? width;
  final double? height;
  final BoxFit fit;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor == const Color(0xFF1769AA)
        ? null
        : _accentColorFilter(accentColor);
    final image = Image.asset(
      'assets/brand/logo.png',
      fit: fit,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Símbolo de SearchTeach',
    );
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Expanded(
              child: accent == null
                  ? image
                  : ColorFiltered(colorFilter: accent, child: image),
            ),
            const SizedBox(height: 2),
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'SearchTeach',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ColorFilter _accentColorFilter(Color accent) {
    const sourceDarkGreen = 45.0;
    const sourceAccentGreen = 116.0;
    final scale = 1 / (sourceAccentGreen - sourceDarkGreen);
    final red = (accent.r * 255).roundToDouble();
    final green = (accent.g * 255).roundToDouble();
    final blue = (accent.b * 255).roundToDouble();
    return ColorFilter.matrix([
      0, red * scale, 0, 0, -red * sourceDarkGreen * scale,
      0, green * scale, 0, 0, -green * sourceDarkGreen * scale,
      0, blue * scale, 0, 0, -blue * sourceDarkGreen * scale,
      0, 0, 0, 1, 0,
    ]);
  }
}
