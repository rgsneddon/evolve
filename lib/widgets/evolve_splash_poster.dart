import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Static splash background — no video decode or animation.
class EvolveSplashPoster extends StatelessWidget {
  const EvolveSplashPoster({
    super.key,
    this.assetPath = 'assets/banner/evolve.jpg',
  });

  final String assetPath;

  /// Wide header art (~3.2:1); matches [EvolveBanner] proportions.
  static const aspectRatio = 3.2;

  static const _backdropColor = Color(0xFF0A0E18);

  /// Android login uses proportional fit so the full wordmark stays visible.
  @visibleForTesting
  static bool get usesProportionalFit =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    if (usesProportionalFit) {
      return ColoredBox(
        color: _backdropColor,
        child: _ProportionalSplashBanner(assetPath: assetPath),
      );
    }

    return SizedBox.expand(
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.low,
        semanticLabel: 'Evolve splash',
        errorBuilder: (_, __, ___) => const ColoredBox(color: _backdropColor),
      ),
    );
  }
}

class _ProportionalSplashBanner extends StatelessWidget {
  const _ProportionalSplashBanner({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = (width / EvolveSplashPoster.aspectRatio)
            .clamp(56.0, constraints.maxHeight * 0.42);
        final topInset = constraints.maxHeight * 0.05;

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: SizedBox(
              width: width,
              height: height,
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                semanticLabel: 'Evolve splash',
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: EvolveSplashPoster._backdropColor),
              ),
            ),
          ),
        );
      },
    );
  }
}