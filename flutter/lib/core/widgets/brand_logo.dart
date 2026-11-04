import 'package:flutter/material.dart';

/// Shared SearchTeach mark used by every Flutter platform.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
  });

  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/brand/logo.png',
        width: width,
        height: height,
        fit: fit,
        color: color,
        colorBlendMode: color == null ? null : BlendMode.srcIn,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Logo de SearchTeach',
      );
}
