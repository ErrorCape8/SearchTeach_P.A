import 'package:flutter/material.dart';

/// Shared SearchTeach mark used by every Flutter platform.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Expanded(
              child: Image.asset(
                'assets/brand/logo_black.png',
                fit: fit,
                filterQuality: FilterQuality.high,
                semanticLabel: 'Símbolo de SearchTeach',
              ),
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
}
