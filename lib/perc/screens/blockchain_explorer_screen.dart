import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../models/perc_block.dart';
import '../perc_chain_constants.dart';
import '../providers/perc_wallet_provider.dart';
import '../widgets/wallet_creator_credit.dart';

/// Graph-based dapp — historical Perccent chain blocks inside the wallet.
class BlockchainExplorerScreen extends StatelessWidget {
  const BlockchainExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    final strings = AppLocalizations.of(context.watch<LocaleProvider>().config);
    final blocks = wallet.blocks;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('wallet_explorer_title')),
      ),
      body: SafeArea(
        child: blocks.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    strings.t('wallet_explorer_empty'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF9BA3B8)),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _heightCard(wallet.blockHeight, strings),
                        const SizedBox(height: 16),
                        _graphCard(blocks, strings),
                        const SizedBox(height: 16),
                        _cumulativeCard(blocks, strings),
                        const SizedBox(height: 20),
                        Text(
                          strings.t('wallet_explorer_history'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF9BA3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...blocks.reversed.map(
                          (b) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _blockTile(b, strings),
                          ),
                        ),
                        WalletCreatorCredit(strings: strings),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _heightCard(int height, AppLocalizations strings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('wallet_explorer_block_label'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 6),
            Text(
              '#$height',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Color(0xFF00D9C0),
                height: 1,
              ),
            ),
            Text(
              strings.t('wallet_explorer_subtitle'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _graphCard(List<PercBlock> blocks, AppLocalizations strings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('wallet_explorer_emission_chart'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: CustomPaint(
                painter: _BlockEmissionPainter(blocks: blocks),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _legendDot(const Color(0xFF6C63FF)),
                const SizedBox(width: 6),
                Text(
                  strings.t('wallet_explorer_legend_emission'),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
                ),
                const SizedBox(width: 16),
                _legendDot(const Color(0xFF00D9C0)),
                const SizedBox(width: 6),
                Text(
                  strings.t('wallet_explorer_legend_txs'),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _cumulativeCard(List<PercBlock> blocks, AppLocalizations strings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('wallet_explorer_cumulative_chart'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: CustomPaint(
                painter: _CumulativeMintPainter(blocks: blocks),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blockTile(PercBlock block, AppLocalizations strings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${block.index}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6C63FF),
                  ),
                ),
                const Spacer(),
                Text(
                  block.timestamp.toLocal().toString().substring(0, 19),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
                ),
              ],
            ),
            if (block.triggerUsername != null) ...[
              const SizedBox(height: 4),
              Text(
                strings
                    .t('wallet_explorer_trigger')
                    .replaceAll('{user}', block.triggerUsername!),
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (block.isGenesisRenewal) ...[
              const SizedBox(height: 4),
              Text(
                strings
                    .t('wallet_explorer_genesis_renewal')
                    .replaceAll('{cycle}', '${block.treasuryCycle}'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFB347),
                ),
              ),
            ],
            if (block.treasuryEmitted.isPositive) ...[
              const SizedBox(height: 4),
              Text(
                '+${block.treasuryEmitted.display} ${PercChainConstants.currencySymbol} ${PercChainConstants.currencyName} treasury',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6C63FF)),
              ),
            ],
            Text(
              strings
                  .t('wallet_explorer_tx_count')
                  .replaceAll('{count}', '${block.transactions.length}'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockEmissionPainter extends CustomPainter {
  _BlockEmissionPainter({required this.blocks});

  final List<PercBlock> blocks;

  @override
  void paint(Canvas canvas, Size size) {
    if (blocks.isEmpty) return;

    final pad = 12.0;
    final chartW = size.width - pad * 2;
    final chartH = size.height - pad * 2;
    final maxEmission = blocks
        .map((b) => b.treasuryEmitted.asPerc)
        .fold<double>(0, math.max)
        .clamp(0.001, double.infinity);
    final maxTxs = blocks
        .map((b) => b.transactions.length)
        .fold<int>(0, math.max)
        .clamp(1, 999);
    final barW = chartW / blocks.length * 0.7;
    final gap = chartW / blocks.length;

    final grid = Paint()
      ..color = const Color(0xFF2A3142)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(pad, size.height - pad),
      Offset(size.width - pad, size.height - pad),
      grid,
    );

    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final x = pad + i * gap + (gap - barW) / 2;
      final emissionH = (b.treasuryEmitted.asPerc / maxEmission) * chartH * 0.85;
      final txH = (b.transactions.length / maxTxs) * chartH * 0.35;

      final emissionPaint = Paint()..color = const Color(0xFF6C63FF);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - pad - emissionH, barW / 2, emissionH),
          const Radius.circular(3),
        ),
        emissionPaint,
      );

      final txPaint = Paint()..color = const Color(0xFF00D9C0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + barW / 2,
            size.height - pad - txH,
            barW / 2,
            txH,
          ),
          const Radius.circular(3),
        ),
        txPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BlockEmissionPainter old) =>
      old.blocks != blocks;
}

class _CumulativeMintPainter extends CustomPainter {
  _CumulativeMintPainter({required this.blocks});

  final List<PercBlock> blocks;

  @override
  void paint(Canvas canvas, Size size) {
    if (blocks.isEmpty) return;

    final pad = 12.0;
    var cumulative = 0.0;
    final points = <Offset>[];
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].isGenesisRenewal) cumulative = 0;
      cumulative += blocks[i].treasuryEmitted.asPerc;
      final x = pad + (size.width - pad * 2) * (i / math.max(blocks.length - 1, 1));
      final maxY = PercChainConstants.maxSupply.asPerc;
      final y = size.height - pad - (cumulative / maxY).clamp(0.0, 1.0) * (size.height - pad * 2);
      points.add(Offset(x, y));
    }

    final line = Paint()
      ..color = const Color(0xFF00D9C0)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      canvas.drawCircle(points.first, 4, Paint()..color = const Color(0xFF00D9C0));
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, line);

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00D9C0).withOpacity(0.25),
          const Color(0xFF00D9C0).withOpacity(0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height - pad)
      ..lineTo(points.first.dx, size.height - pad)
      ..close();
    canvas.drawPath(fillPath, fill);
  }

  @override
  bool shouldRepaint(covariant _CumulativeMintPainter old) =>
      old.blocks != blocks;
}