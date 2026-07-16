import 'dart:async';

import 'package:evolve/platform/evolve_window_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

class _RecordingWindowOps implements EvolveWindowOps {
  bool preventCloseEnabled = false;
  WindowListener? registeredListener;
  final Completer<void> destroyCompleter = Completer<void>();
  int destroyCallCount = 0;

  @override
  Future<void> setPreventClose(bool value) async {
    preventCloseEnabled = value;
  }

  @override
  Future<void> destroy() async {
    destroyCallCount++;
    if (!destroyCompleter.isCompleted) {
      destroyCompleter.complete();
    }
  }

  @override
  void addListener(WindowListener listener) {
    registeredListener = listener;
  }
}

void main() {
  test('register enables prevent-close interception on the desktop path',
      () async {
    final ops = _RecordingWindowOps();

    await registerEvolveWindowLifecycle(
      windowOps: ops,
      enabled: true,
    );

    expect(ops.preventCloseEnabled, isTrue);
    expect(ops.registeredListener, isA<EvolveWindowLifecycle>());
    expect(EvolveWindowLifecycle.instance, isNotNull);
  });

  test('onWindowClose destroys window (real WM_CLOSE path)', () async {
    final ops = _RecordingWindowOps();
    await registerEvolveWindowLifecycle(
      windowOps: ops,
      enabled: true,
    );

    ops.registeredListener!.onWindowClose();
    await ops.destroyCompleter.future.timeout(const Duration(seconds: 5));

    expect(ops.destroyCallCount, 1);
  });
}