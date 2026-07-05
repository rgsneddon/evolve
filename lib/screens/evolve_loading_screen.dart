import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../perc/perc_app_version.dart';

/// Animated launch screen — EVOLVE title, FCG suite subtitle, and release version.
class EvolveLoadingScreen extends StatefulWidget {
  const EvolveLoadingScreen({
    super.key,
    this.duration = const Duration(seconds: 4),
  });

  final Duration duration;

  @visibleForTesting
  static Duration? durationOverride;

  static Duration get splashDuration => durationOverride ?? const Duration(seconds: 4);

  static String get versionLabel =>
      'v${PercAppVersion.releaseOf(PercAppVersion.current)}';

  @override
  State<EvolveLoadingScreen> createState() => _EvolveLoadingScreenState();
}

class _EvolveLoadingScreenState extends State<EvolveLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final duration = widget.duration == const Duration(seconds: 4)
        ? EvolveLoadingScreen.splashDuration
        : widget.duration;
    _controller = AnimationController(vsync: this, duration: duration)..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _interval(double start, double end) {
    final t = _controller.value;
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final titleOpacity = Curves.easeOut.transform(_interval(0.05, 0.35));
        final titleScale =
            0.88 + 0.12 * Curves.easeOutBack.transform(_interval(0.05, 0.4)).clamp(0.0, 1.0);
        final subtitleOpacity = Curves.easeOut.transform(_interval(0.28, 0.55));
        final subtitleSlide = 18 * (1 - Curves.easeOutCubic.transform(_interval(0.28, 0.55)));
        final lineWidth = Curves.easeInOut.transform(_interval(0.42, 0.62));
        final versionOpacity = Curves.easeOut.transform(_interval(0.58, 0.82));
        final glowPulse = 0.55 + 0.45 * Curves.easeInOut.transform(_interval(0.7, 1.0));

        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0A0E18),
                        Color(0xFF12182A),
                        Color(0xFF0D0F14),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -140,
                right: -100,
                child: Opacity(
                  opacity: 0.12 * glowPulse,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -120,
                left: -80,
                child: Opacity(
                  opacity: 0.1 * glowPulse,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF00D9C0),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Opacity(
                      opacity: titleOpacity,
                      child: Transform.scale(
                        scale: titleScale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFF8B83FF),
                                  Color(0xFF6C63FF),
                                  Color(0xFF00D9C0),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'EVOLVE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 6,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Opacity(
                              opacity: lineWidth,
                              child: Container(
                                width: 72 * lineWidth,
                                height: 2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6C63FF),
                                      Color(0xFF00D9C0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Transform.translate(
                              offset: Offset(0, subtitleSlide),
                              child: Opacity(
                                opacity: subtitleOpacity,
                                child: const Text(
                                  'Full Community Governance Suite',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.4,
                                    color: Color(0xFFD8DCE8),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),
                            Opacity(
                              opacity: versionOpacity,
                              child: Text(
                                EvolveLoadingScreen.versionLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 2.5,
                                  color: Color(0xFF9BA3B8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Opacity(
                              opacity: versionOpacity * 0.85,
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  value: _controller.isAnimating ? null : 1,
                                  color: const Color(0xFF6C63FF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}