import 'package:flutter/material.dart';

import '../services/app_performance.dart';
import 'evolve_splash_poster.dart';

/// Full-bleed article banner — continuous horizontal pan loop (seamless tile).
class EvolveBannerLoop extends StatefulWidget {
  const EvolveBannerLoop({
    super.key,
    this.assetPath = 'assets/banner/evolve.jpg',
    this.loopDuration = AppPerformance.bannerLoopDuration,
  });

  static const defaultAssetPath = 'assets/banner/evolve.jpg';

  final String assetPath;
  final Duration loopDuration;

  @visibleForTesting
  static Duration? loopDurationOverride;

  @override
  State<EvolveBannerLoop> createState() => _EvolveBannerLoopState();
}

class _EvolveBannerLoopState extends State<EvolveBannerLoop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  Duration get _loopDuration =>
      EvolveBannerLoop.loopDurationOverride ?? widget.loopDuration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(vsync: this, duration: _loopDuration);
    _startIfNeeded();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _startIfNeeded();
  }

  void _startIfNeeded() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final active = lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.detached &&
        lifecycle != AppLifecycleState.hidden;
    if (!active) {
      _controller.stop();
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return EvolveSplashPoster(assetPath: widget.assetPath);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;
        if (height <= 0 || width <= 0) return const SizedBox.shrink();

        // Pan one tile width per loop — duplicate tiles hide the reset seam.
        final tileWidth = width * 1.35;

        return ClipRect(
          child: SizedBox(
            width: width,
            height: height,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final offset = -_controller.value * tileWidth;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _tile(tileWidth, height),
                        _tile(tileWidth, height),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tile(double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        widget.assetPath,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.low,
        semanticLabel: 'Evolve banner',
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF12182A),
          alignment: Alignment.center,
          child: const Text(
            'EVOLVE',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              color: Color(0xFF6C63FF),
            ),
          ),
        ),
      ),
    );
  }
}