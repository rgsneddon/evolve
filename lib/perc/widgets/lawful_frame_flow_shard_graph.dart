import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../models/perc_side_chain.dart';
import '../providers/perc_wallet_provider.dart';
import '../services/perc_shard_density.dart';
import '../services/perc_ward_bundler.dart';

/// Animated lawful frame-flow split graph — wards bundle 10,000 microblocks each.
class LawfulFrameFlowShardGraph extends StatefulWidget {
  const LawfulFrameFlowShardGraph({
    super.key,
    required this.wallet,
    required this.strings,
  });

  final PercWalletProvider wallet;
  final AppLocalizations strings;

  @override
  State<LawfulFrameFlowShardGraph> createState() =>
      _LawfulFrameFlowShardGraphState();
}

class _LawfulFrameFlowShardGraphState extends State<LawfulFrameFlowShardGraph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  PercShardDensity? _density;
  var _building = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 48),
    )..repeat();
    _rebuildDensity();
  }

  @override
  void didUpdateWidget(covariant LawfulFrameFlowShardGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSide = oldWidget.wallet.sideChain;
    final newSide = widget.wallet.sideChain;
    if (oldWidget.wallet.microblockCount != widget.wallet.microblockCount ||
        oldWidget.wallet.totalMicroblocks != widget.wallet.totalMicroblocks ||
        oldSide.pendingMicroblocks != newSide.pendingMicroblocks) {
      _rebuildDensity();
    }
  }

  Future<void> _rebuildDensity() async {
    if (_building) return;
    _building = true;
    final wards = PercWardBundler.fromSideChain(widget.wallet.sideChain);
    final built = await PercShardDensity.buildForWards(wards: wards);
    if (!mounted) return;
    setState(() {
      _density = built;
      _building = false;
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.wallet.sideChain;
    final strings = widget.strings;
    final wards = PercWardBundler.fromSideChain(side);
    final progress = side.sealProgress;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF080C14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2F6F8F), width: 1.2),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.t('wallet_explorer_frame_flow_title'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFB347),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings
                .t('wallet_explorer_frame_flow_subtitle')
                .replaceAll('{bundle}', '${wards.microblocksPerWard}'),
            style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _degeneratePanel(strings)),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: _graphPanel(side, strings, wards, progress),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _lawfulPanel(side, strings, wards)),
                  ],
                );
              }
              return Column(
                children: [
                  _graphPanel(side, strings, wards, progress),
                  const SizedBox(height: 10),
                  _lawfulPanel(side, strings, wards),
                  const SizedBox(height: 10),
                  _degeneratePanel(strings),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            strings.t('wallet_explorer_frame_flow_status'),
            style: const TextStyle(fontSize: 10, color: Color(0xFF7A8299), height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _graphPanel(
    PercSideChainState side,
    AppLocalizations strings,
    PercWardView wards,
    double progress,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3BC9FF).withOpacity(0.55)),
        color: const Color(0xFF0A1018),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Text(
            strings.t('wallet_explorer_frame_flow_center'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7FDBFF),
            ),
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _density == null
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedBuilder(
                          animation: _spin,
                          builder: (context, _) => CustomPaint(
                            painter: _LawfulFrameFlowPainter(
                              density: _density!,
                              wards: wards,
                              rotation: _spin.value * math.pi * 2,
                              pulse:
                                  (math.sin(_spin.value * math.pi * 4) + 1) / 2,
                              progress: progress,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        _graphOverlay(strings, wards),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings
                .t('wallet_explorer_ward_cycle')
                .replaceAll('{completed}', '${wards.completedWardsInCycle}')
                .replaceAll('{total}', '${wards.wardsPerSealCycle}')
                .replaceAll('{ward}', '${wards.currentWardIndex}')
                .replaceAll('{pending}', '${wards.microblocksInCurrentWard}')
                .replaceAll('{bundle}', '${wards.microblocksPerWard}'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Color(0xFFB8D4FF)),
          ),
          Text(
            strings
                .t('wallet_explorer_ward_field_count')
                .replaceAll('{wards}', '${wards.wardsPerSealCycle}')
                .replaceAll('{lit}', '${wards.completedWardsInCycle}')
                .replaceAll('{bundle}', '${wards.microblocksPerWard}'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9BA3B8)),
          ),
          Text(
            strings
                .t('wallet_explorer_ward_lifetime')
                .replaceAll('{count}', '${wards.totalWardsEver}'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: Color(0xFF7A8299)),
          ),
          Text(
            '${strings.t('wallet_sidechain_id')}: ${side.sideChainId}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Color(0xFF6C63FF)),
          ),
        ],
      ),
    );
  }

  Widget _graphOverlay(AppLocalizations strings, PercWardView wards) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 8,
          right: 8,
          child: _labelChip(
            strings.t('wallet_explorer_label_frame'),
            const Color(0xFF3BC9FF),
          ),
        ),
        Positioned(
          right: 8,
          top: 56,
          child: _labelChip(
            strings.t('wallet_explorer_label_drift'),
            const Color(0xFF5CE0A8),
          ),
        ),
        Positioned(
          left: 8,
          top: 56,
          child: _labelChip(
            strings.t('wallet_explorer_ward_title'),
            const Color(0xFF5CE0A8),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 72,
          child: _labelChip(
            strings.t('wallet_explorer_label_split'),
            const Color(0xFFB388FF),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: _labelChip(
            strings.t('wallet_explorer_label_projector'),
            const Color(0xFFFFB347),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 28,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF060A10).withOpacity(0.82),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF5CE0A8).withOpacity(0.45),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: CustomPaint(
                painter: _WardHeatmapPainter(wards: wards),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 8,
          child: Text(
            strings.t('wallet_explorer_ward_legend'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 7,
              color: Color(0xFF6C7A8F),
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _labelChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.65)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _degeneratePanel(AppLocalizations strings) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF8C42).withOpacity(0.55)),
        color: const Color(0xFF141018),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.t('wallet_explorer_degenerate_title'),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF8C42),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.t('wallet_explorer_degenerate_body'),
            style: const TextStyle(fontSize: 9, color: Color(0xFF9BA3B8), height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _lawfulPanel(
    PercSideChainState side,
    AppLocalizations strings,
    PercWardView wards,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3BC9FF).withOpacity(0.45)),
        color: const Color(0xFF0C121C),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.t('wallet_explorer_lawful_title'),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7FDBFF),
            ),
          ),
          const SizedBox(height: 6),
          _lawfulLine('Jμ = ρt (nμ + vμ)'),
          _lawfulLine('nμ vμ = 0'),
          _lawfulLine('h(n)μν built from frame'),
          const SizedBox(height: 6),
          Text(
            strings
                .t('wallet_explorer_ward_pending')
                .replaceAll('{ward}', '${wards.currentWardIndex}')
                .replaceAll('{pending}', '${wards.microblocksInCurrentWard}')
                .replaceAll('{bundle}', '${wards.microblocksPerWard}'),
            style: const TextStyle(fontSize: 9, color: Color(0xFF5CE0A8)),
          ),
          Text(
            strings
                .t('wallet_sidechain_pending')
                .replaceAll('{pending}', _formatShardCount(wards.pendingMicroblocks))
                .replaceAll('{total}', _formatShardCount(wards.microblocksPerBlock)),
            style: const TextStyle(fontSize: 9, color: Color(0xFF9BA3B8)),
          ),
          Text(
            '${strings.t('wallet_sidechain_height')}: ${side.microblockHeight}',
            style: const TextStyle(fontSize: 9, color: Color(0xFF9BA3B8)),
          ),
        ],
      ),
    );
  }

  Widget _lawfulLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontFamily: 'monospace',
          color: Color(0xFFB8D4FF),
        ),
      ),
    );
  }

  static String _formatShardCount(int n) {
    if (n >= 1000000) {
      final m = n / 1000000;
      return m == m.roundToDouble()
          ? '${m.toInt()}M'
          : '${m.toStringAsFixed(2)}M';
    }
    return '$n';
  }
}

class _LawfulFrameFlowPainter extends CustomPainter {
  _LawfulFrameFlowPainter({
    required this.density,
    required this.wards,
    required this.rotation,
    required this.pulse,
    required this.progress,
  });

  final PercShardDensity density;
  final PercWardView wards;
  final double rotation;
  final double pulse;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.46;

    _paintBackground(canvas, size);
    _paintWedges(canvas, center, radius);
    _paintWardAnnulus(canvas, center, radius);
    _paintSpokes(canvas, center, radius);
    _paintShardField(canvas, center, radius);
    _paintCore(canvas, center, radius);
    _paintProgressRing(canvas, center, radius);
    _paintWardProgressRing(canvas, center, radius);
  }

  /// Ward bundle fill inside the microblock shard field (aggregate, not per-ward).
  void _paintWardAnnulus(Canvas canvas, Offset center, double radius) {
    final total = wards.wardsPerSealCycle;
    if (total <= 0) return;

    final inner = radius * 0.24;
    final outer = radius * 0.86;
    final start = -math.pi / 2;
    final completedSweep = math.pi * 2 * wards.sealCycleWardProgress;

    void drawSector(double sweep, Color color, double opacity) {
      if (sweep <= 0) return;
      final path = Path()
        ..moveTo(
          center.dx + math.cos(start) * inner,
          center.dy + math.sin(start) * inner,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: outer),
          start,
          sweep,
          false,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: inner),
          start + sweep,
          -sweep,
          false,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );
    }

    drawSector(completedSweep, const Color(0xFF5CE0A8), 0.16);

    if (wards.microblocksInCurrentWard > 0) {
      final wardSlice = math.pi * 2 / total;
      final currentSweep = wardSlice * wards.currentWardProgress;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(start + completedSweep);
      canvas.translate(-center.dx, -center.dy);
      drawSector(currentSweep, const Color(0xFF3BC9FF), 0.22);
      canvas.restore();
    }
  }

  /// Outer ward seal ring — green = bundled wards, blue = active ward fill.
  void _paintWardProgressRing(Canvas canvas, Offset center, double radius) {
    final ring = radius * 1.08;
    const stroke = 3.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ring),
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..color = const Color(0xFF1A2840)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    final wardSweep = math.pi * 2 * wards.sealCycleWardProgress;
    if (wardSweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ring),
        -math.pi / 2,
        wardSweep,
        false,
        Paint()
          ..color = const Color(0xFF5CE0A8).withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    if (wards.microblocksInCurrentWard > 0 && wards.wardsPerSealCycle > 0) {
      final wardSlice = math.pi * 2 / wards.wardsPerSealCycle;
      final start = -math.pi / 2 + wardSweep;
      final currentSweep = wardSlice * wards.currentWardProgress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ring),
        start,
        currentSweep,
        false,
        Paint()
          ..color = const Color(0xFF3BC9FF).withOpacity(0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          size.center(Offset.zero),
          size.shortestSide * 0.7,
          [
            const Color(0xFF101828),
            const Color(0xFF060A10),
          ],
        ),
    );
  }

  void _paintWedges(Canvas canvas, Offset center, double radius) {
    const wedges = 5;
    for (var i = 0; i < wedges; i++) {
      final start = rotation + i * (math.pi * 2 / wedges);
      final sweep = math.pi * 2 / wedges * 0.72;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius * 0.92),
          start,
          sweep,
          false,
        )
        ..close();
      final colors = [
        const Color(0xFF6C63FF),
        const Color(0xFF00D9C0),
        const Color(0xFF3BC9FF),
        const Color(0xFFB388FF),
        const Color(0xFF5CE0A8),
      ];
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[i % colors.length].withOpacity(0.08 + pulse * 0.04)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _paintSpokes(Canvas canvas, Offset center, double radius) {
    const spokes = 96;
    for (var i = 0; i < spokes; i++) {
      final angle = rotation * 0.35 + i * (math.pi * 2 / spokes);
      final len = radius * (0.35 + (i % 7) / 12.0);
      final end = Offset(
        center.dx + math.cos(angle) * len,
        center.dy + math.sin(angle) * len,
      );
      canvas.drawLine(
        center,
        end,
        Paint()
          ..color = Color.lerp(
                const Color(0xFF3BC9FF),
                const Color(0xFFFFB347),
                (i % 11) / 11.0,
              )
              .withOpacity(0.12 + pulse * 0.08)
          ..strokeWidth = 0.6,
      );
    }
  }

  void _paintShardField(Canvas canvas, Offset center, double radius) {
    final maxD = density.maxDensity.toDouble();
    final maxL = density.maxLitDensity.toDouble();
    final aBins = density.angularBins;
    final rBins = density.radialBins;

    for (var r = 0; r < rBins; r++) {
      final r0 = (r / rBins) * radius;
      final r1 = ((r + 1) / rBins) * radius;
      for (var a = 0; a < aBins; a++) {
        final idx = r * aBins + a;
        final count = density.density[idx];
        if (count == 0) continue;
        final lit = density.litDensity[idx];
        final angle0 = rotation + a * (math.pi * 2 / aBins);
        final angle1 = angle0 + (math.pi * 2 / aBins);

        final base = (count / maxD).clamp(0.05, 1.0);
        final litMix = lit > 0 ? (lit / maxL).clamp(0.2, 1.0) : 0.0;
        final color = Color.lerp(
              Color.lerp(
                const Color(0xFF2A1848),
                const Color(0xFF3BC9FF),
                base * 0.75,
              ),
              const Color(0xFF5CE0A8),
              litMix * 0.85,
            );

        final path = Path()
          ..moveTo(
            center.dx + math.cos(angle0) * r0,
            center.dy + math.sin(angle0) * r0,
          )
          ..lineTo(
            center.dx + math.cos(angle0) * r1,
            center.dy + math.sin(angle0) * r1,
          )
          ..lineTo(
            center.dx + math.cos(angle1) * r1,
            center.dy + math.sin(angle1) * r1,
          )
          ..lineTo(
            center.dx + math.cos(angle1) * r0,
            center.dy + math.sin(angle1) * r0,
          )
          ..close();

        canvas.drawPath(
          path,
          Paint()
            ..color = color.withOpacity(0.35 + base * 0.45)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  void _paintCore(Canvas canvas, Offset center, double radius) {
    final coreR = radius * (0.06 + pulse * 0.015);
    canvas.drawCircle(
      center,
      coreR * 2.2,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          coreR * 2.2,
          [
            const Color(0xFFFFB347).withOpacity(0.55),
            const Color(0xFFFFB347).withOpacity(0.0),
          ],
        ),
    );
    canvas.drawCircle(
      center,
      coreR,
      Paint()..color = const Color(0xFFFFD27A),
    );
    canvas.drawCircle(
      center,
      coreR * 0.55,
      Paint()..color = const Color(0xFFFFF2C2),
    );
  }

  void _paintProgressRing(Canvas canvas, Offset center, double radius) {
    final ring = radius * 1.02;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ring),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = const Color(0xFF5CE0A8).withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LawfulFrameFlowPainter old) =>
      old.density != density ||
      old.wards.completedWardsInCycle != wards.completedWardsInCycle ||
      old.wards.microblocksInCurrentWard != wards.microblocksInCurrentWard ||
      old.wards.pendingMicroblocks != wards.pendingMicroblocks ||
      old.rotation != rotation ||
      old.pulse != pulse ||
      old.progress != progress;
}

/// Heatmap of all wards in the current seal cycle (100 × 100 = 10,000 wards).
class _WardHeatmapPainter extends CustomPainter {
  _WardHeatmapPainter({required this.wards});

  final PercWardView wards;

  @override
  void paint(Canvas canvas, Size size) {
    final total = wards.wardsPerSealCycle;
    if (total <= 0) return;

    final cols = math.sqrt(total).ceil().clamp(1, 200);
    final rows = (total / cols).ceil();
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF060A10),
    );

    for (var i = 0; i < total; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final fill = wards.wardFillRatio(i);
      final color = fill >= 1
          ? const Color(0xFF5CE0A8)
          : fill > 0
              ? Color.lerp(
                    const Color(0xFF1A2840),
                    const Color(0xFF3BC9FF),
                    fill,
                  )
              : const Color(0xFF121820);

      canvas.drawRect(
        Rect.fromLTWH(col * cellW, row * cellH, cellW - 0.5, cellH - 0.5),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WardHeatmapPainter old) =>
      old.wards.completedWardsInCycle != wards.completedWardsInCycle ||
      old.wards.microblocksInCurrentWard != wards.microblocksInCurrentWard ||
      old.wards.wardsPerSealCycle != wards.wardsPerSealCycle;
}