import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/construct_meta.dart';
import '../models/chronoflux_construct_snapshot.dart';
import '../providers/perc_wallet_provider.dart';
import '../services/chronoflux_variable_history.dart';

/// Five-point Chronoflux graphs — pentagon radar plus per-variable time series.
class ChronofluxFivePointGraphPanel extends StatelessWidget {
  const ChronofluxFivePointGraphPanel({
    super.key,
    required this.wallet,
    required this.strings,
    this.compact = false,
  });

  final PercWalletProvider wallet;
  final AppLocalizations strings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final history = ChronofluxVariableHistory.fromBlocks(wallet.blocks);
    final latest = history.isNotEmpty ? history.last : null;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('wallet_chronoflux_graph_title'),
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.t('wallet_chronoflux_graph_note'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8), height: 1.4),
            ),
            const SizedBox(height: 12),
            if (latest == null)
              Text(
                strings.t('wallet_chronoflux_graph_empty'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
              )
            else ...[
              SizedBox(
                height: compact ? 150 : 190,
                child: CustomPaint(
                  painter: _ChronofluxPentagonPainter(
                    values: latest.orderedValues,
                    labels: ChronofluxConstructSnapshot.symbols,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 12),
              ..._variableRows(history),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _variableRows(List<ChronofluxConstructSnapshot> history) {
    final labels = _constructLabels();
    final times = ChronofluxVariableHistory.timeLabels(history);
    final rows = <Widget>[];

    for (var i = 0; i < ChronofluxConstructSnapshot.inputOrder.length; i++) {
      final key = ChronofluxConstructSnapshot.inputOrder[i];
      final symbol = ChronofluxConstructSnapshot.symbols[i];
      final series = ChronofluxVariableHistory.seriesForKey(history, key);
      final color = _colorForKey(key);

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${labels[key] ?? key} ($symbol)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  if (series.isNotEmpty)
                    Text(
                      '${series.last.round()}/100',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF9BA3B8)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: compact ? 44 : 52,
                child: CustomPaint(
                  painter: _FivePointSeriesPainter(
                    values: _padSeries(series),
                    color: color,
                    timeLabels: times,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  List<double> _padSeries(List<double> series) {
    if (series.length >= ChronofluxVariableHistory.pointCount) {
      return series.sublist(series.length - ChronofluxVariableHistory.pointCount);
    }
    final padded = List<double>.filled(
      ChronofluxVariableHistory.pointCount - series.length,
      series.isEmpty ? 0 : series.first,
    );
    padded.addAll(series);
    return padded;
  }

  Map<String, String> _constructLabels() => {
        'continuum': strings.t('label_continuum'),
        'vortex': strings.t('label_vortex'),
        'shear': strings.t('label_shear'),
        'resistance': strings.t('label_resistance'),
        'flow': strings.t('label_flow'),
      };

  Color _colorForKey(String key) {
    switch (key) {
      case 'vortex':
        return ConstructMeta.all[0].color;
      case 'shear':
        return ConstructMeta.all[1].color;
      case 'resistance':
        return ConstructMeta.all[2].color;
      case 'flow':
        return ConstructMeta.all[3].color;
      case 'continuum':
      default:
        return const Color(0xFF9BA3B8);
    }
  }
}

class _ChronofluxPentagonPainter extends CustomPainter {
  _ChronofluxPentagonPainter({
    required this.values,
    required this.labels,
  });

  final List<double> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.36;
    final angles = List.generate(
      5,
      (i) => -math.pi / 2 + i * 2 * math.pi / 5,
    );

    final grid = Paint()
      ..color = const Color(0xFF2A3142)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      final path = Path();
      for (var i = 0; i < 5; i++) {
        final p = Offset(
          center.dx + r * math.cos(angles[i]),
          center.dy + r * math.sin(angles[i]),
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, grid);
    }

    for (var i = 0; i < 5; i++) {
      final outer = Offset(
        center.dx + radius * math.cos(angles[i]),
        center.dy + radius * math.sin(angles[i]),
      );
      canvas.drawLine(center, outer, grid);
    }

    final dataPath = Path();
    for (var i = 0; i < 5; i++) {
      final v = (values[i] / 100).clamp(0.0, 1.0);
      final p = Offset(
        center.dx + radius * v * math.cos(angles[i]),
        center.dy + radius * v * math.sin(angles[i]),
      );
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..color = const Color(0xFF00D9C0).withOpacity(0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = const Color(0xFF00D9C0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final textStyle = const TextStyle(fontSize: 10, color: Color(0xFF9BA3B8));
    for (var i = 0; i < 5; i++) {
      final labelR = radius + 14;
      final lp = Offset(
        center.dx + labelR * math.cos(angles[i]),
        center.dy + labelR * math.sin(angles[i]),
      );
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ChronofluxPentagonPainter old) =>
      old.values != values;
}

class _FivePointSeriesPainter extends CustomPainter {
  _FivePointSeriesPainter({
    required this.values,
    required this.color,
    required this.timeLabels,
  });

  final List<double> values;
  final Color color;
  final List<String> timeLabels;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 8.0;
    final chartW = size.width - pad * 2;
    final chartH = size.height - pad * 2 - 12;
    final baseY = size.height - pad - 12;

    final grid = Paint()
      ..color = const Color(0xFF2A3142)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(pad, baseY), Offset(size.width - pad, baseY), grid);

    final n = values.length;
    final gap = chartW / (n - 1).clamp(1, n);
    final points = <Offset>[];

    for (var i = 0; i < n; i++) {
      final x = pad + i * gap;
      final y = baseY - (values[i] / 100).clamp(0.0, 1.0) * chartH;
      points.add(Offset(x, y));
    }

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    final dot = Paint()..color = color;
    for (final p in points) {
      canvas.drawCircle(p, 3.5, dot);
    }

    final labelStyle = const TextStyle(fontSize: 8, color: Color(0xFF6B7280));
    for (var i = 0; i < n; i++) {
      final label = i < timeLabels.length ? timeLabels[i] : '${i + 1}';
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: gap);
      tp.paint(
        canvas,
        Offset(points[i].dx - tp.width / 2, size.height - pad - 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FivePointSeriesPainter old) =>
      old.values != values || old.color != color;
}