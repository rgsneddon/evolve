import '../models/perc_block.dart';

/// Average time between main-chain blocks.
class PercBlockTiming {
  const PercBlockTiming._();

  static Duration? averageTimePerBlock(List<PercBlock> blocks) {
    if (blocks.length < 2) return null;
    final span = blocks.last.timestamp.difference(blocks.first.timestamp);
    if (span.isNegative || span == Duration.zero) return null;
    return Duration(
      microseconds: span.inMicroseconds ~/ (blocks.length - 1),
    );
  }

  static String formatAverage(Duration? avg) {
    if (avg == null) return '—';
    if (avg.inDays > 0) {
      return '${avg.inDays}d ${avg.inHours % 24}h ${avg.inMinutes % 60}m';
    }
    if (avg.inHours > 0) {
      return '${avg.inHours}h ${avg.inMinutes % 60}m ${avg.inSeconds % 60}s';
    }
    if (avg.inMinutes > 0) {
      return '${avg.inMinutes}m ${avg.inSeconds % 60}s';
    }
    if (avg.inSeconds > 0) return '${avg.inSeconds}s';
    return '${avg.inMilliseconds}ms';
  }
}