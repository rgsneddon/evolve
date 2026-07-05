import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'evolve_banner_loop.dart';

/// Full-bleed looping splash video for the launch screen.
class EvolveSplashVideo extends StatefulWidget {
  const EvolveSplashVideo({
    super.key,
    this.assetPath = defaultAssetPath,
  });

  static const defaultAssetPath = 'assets/splash/evolve.mp4';

  final String assetPath;

  @visibleForTesting
  static bool? staticFallbackOverride;

  @override
  State<EvolveSplashVideo> createState() => _EvolveSplashVideoState();
}

class _EvolveSplashVideoState extends State<EvolveSplashVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;

  bool get _useStaticFallback =>
      EvolveSplashVideo.staticFallbackOverride == true || _failed;

  @override
  void initState() {
    super.initState();
    if (EvolveSplashVideo.staticFallbackOverride == true) return;
    _initVideo();
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
      await controller.play();
      setState(() {});
    } catch (_) {
      await controller.dispose();
      _controller = null;
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useStaticFallback) return const EvolveBannerLoop();

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