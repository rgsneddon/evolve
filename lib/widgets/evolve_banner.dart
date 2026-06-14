import 'package:flutter/material.dart';

/// Header banner — scales to content width with responsive side buffers.
class EvolveBanner extends StatelessWidget {
  const EvolveBanner({
    super.key,
    this.sideBuffer,
  });

  /// Extra inset inside the content column; defaults scale with viewport width.
  final double? sideBuffer;

  static const _assetPath = 'assets/banner/evolve.jpg';

  /// Wide header art (~3.2:1); keeps height stable when width is constrained.
  static const _aspectRatio = 3.2;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final buffer = sideBuffer ?? (width < 600 ? 8.0 : 16.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final innerWidth = (constraints.maxWidth - (buffer * 2)).clamp(0.0, double.infinity);
        final height = (innerWidth / _aspectRatio).clamp(56.0, 220.0);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: buffer),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: innerWidth,
              height: height,
              child: Image.asset(
                _assetPath,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                semanticLabel: 'Evolve banner',
                errorBuilder: (_, __, ___) => _fallback(height),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fallback(double height) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF151922),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: const Text(
        'EVOLVE',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
          color: Color(0xFFD4AF37),
        ),
      ),
    );
  }
}