import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/app_performance.dart';
import 'evolve_banner_loop.dart';
import 'evolve_splash_poster.dart';

/// Full-bleed looping splash video for the launch screen.
class EvolveSplashVideo extends StatefulWidget {
  const EvolveSplashVideo({
    super.key,
    this.assetPath = defaultAssetPath,
    this.active = true,
  });

  static const defaultAssetPath = 'assets/splash/evolve.mp4';

  final String assetPath;

  /// When false, video decode is paused (saves CPU once auth UI is visible).
  final bool active;

  @visibleForTesting
  static bool? staticFallbackOverride;

  @override
  State<EvolveSplashVideo> createState() => _EvolveSplashVideoState();
}

class _EvolveSplashVideoState extends State<EvolveSplashVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _failed = false;

  bool _animationsReduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  bool _useStaticFallback(BuildContext context) =>
      EvolveSplashVideo.staticFallbackOverride == true ||
      _failed ||
      AppPerformance.useLightweightSplash ||
      _animationsReduced(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (EvolveSplashVideo.staticFallbackOverride == true ||
        AppPerformance.useLightweightSplash) {
      return;
    }
    _initVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncPlayback();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppPerformance.useLightweightSplash ||
        MediaQuery.disableAnimationsOf(context)) {
      _disposeVideo();
    } else if (widget.active) {
      _syncPlayback();
    }
  }

  @override
  void didUpdateWidget(covariant EvolveSplashVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final shouldPlay = widget.active &&
        lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.detached &&
        lifecycle != AppLifecycleState.hidden;
    if (shouldPlay && !controller.value.isPlaying) {
      controller.play();
    } else if (!shouldPlay && controller.value.isPlaying) {
      controller.pause();
    }
  }

  Future<void> _disposeVideo() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.dispose();
    }
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(widget.assetPath);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(0);
      _syncPlayback();
      setState(() {});
    } catch (_) {
      await controller.dispose();
      _controller = null;
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useStaticFallback(context)) {
      if (AppPerformance.useLightweightSplash ||
          _animationsReduced(context)) {
        return const EvolveSplashPoster();
      }
      return const EvolveBannerLoop();
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF0A0E18));
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}