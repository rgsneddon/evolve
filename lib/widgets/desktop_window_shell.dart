import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../platform/desktop_platform.dart';

/// Rounded, edge-to-edge Windows chrome with in-app drag bar and window controls.
class DesktopWindowShell extends StatefulWidget {
  const DesktopWindowShell({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  State<DesktopWindowShell> createState() => _DesktopWindowShellState();
}

class _DesktopWindowShellState extends State<DesktopWindowShell>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (isDesktopWindows) {
      windowManager.addListener(this);
      windowManager.isMaximized().then((value) {
        if (mounted) setState(() => _isMaximized = value);
      });
    }
  }

  @override
  void dispose() {
    if (isDesktopWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindows) return widget.child;

    const bg = Color(0xFF0D0F14);
    final radius = _isMaximized ? 0.0 : 14.0;

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
            border: _isMaximized
                ? null
                : Border.all(color: const Color(0xFF2A3142)),
          ),
          child: Column(
            children: [
              _DesktopTitleBar(
                title: widget.title,
                isMaximized: _isMaximized,
              ),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopTitleBar extends StatelessWidget {
  const _DesktopTitleBar({
    required this.title,
    required this.isMaximized,
  });

  final String title;
  final bool isMaximized;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: Color(0xFF9BA3B8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          WindowCaption(
            brightness: Brightness.dark,
            backgroundColor: Colors.transparent,
          ),
        ],
      ),
    );
  }
}