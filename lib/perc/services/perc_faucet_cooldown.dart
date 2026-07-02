import '../perc_chain_constants.dart';

class PercFaucetCooldown {
  const PercFaucetCooldown._();

  static Duration get period => PercChainConstants.faucetCooldown;

  static Duration? remainingSince(DateTime? lastDraw, DateTime now) {
    if (lastDraw == null) return null;
    final elapsed = now.difference(lastDraw);
    final left = period - elapsed;
    if (left <= Duration.zero) return null;
    return left;
  }

  static bool canDraw(DateTime? lastDraw, DateTime now) =>
      remainingSince(lastDraw, now) == null;

  /// Human-readable wait for popup (e.g. "6h 30m").
  static String formatWait(Duration d) {
    final totalMinutes = d.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    return 'less than 1m';
  }
}