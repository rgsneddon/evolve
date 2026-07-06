import 'package:flutter/material.dart';

/// Static splash background — no video decode or animation.
class EvolveSplashPoster extends StatelessWidget {
  const EvolveSplashPoster({
    super.key,
    this.assetPath = 'assets/banner/evolve.jpg',
  });

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.low,
        semanticLabel: 'Evolve splash',
        errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0A0E18)),
      ),
    );
  }
}