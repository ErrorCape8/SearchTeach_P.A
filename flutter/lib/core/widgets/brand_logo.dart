import 'package:flutter/material.dart';

/// Shared SearchTeach mark used by every Flutter platform.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width, this.height, this.fit = BoxFit.contain});

  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/brand/logo.png',
        width: width,
        height: height,
        fit: fit,
        semanticLabel: 'Logo de SearchTeach',
      );
}
