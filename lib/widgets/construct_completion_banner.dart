import 'package:flutter/material.dart';

/// Advises the user to complete ω/σ/Iτ/Jμ when Grok construal is off.
class ConstructCompletionBanner extends StatelessWidget {
  const ConstructCompletionBanner({
    super.key,
    required this.missingLabels,
    required this.headline,
    required this.body,
    this.grokEnabled = false,
    this.isConstruing = false,
    this.grokReadyMessage,
  });

  final List<String> missingLabels;
  final String headline;
  final String body;
  final bool grokEnabled;
  final bool isConstruing;
  final String? grokReadyMessage;

  @override
  Widget build(BuildContext context) {
    if (grokEnabled) {
      if (isConstruing) {
        return _banner(
          accent: const Color(0xFFF59E0B),
          icon: Icons.auto_awesome,
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  body,
                  style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFFD8DCE8)),
                ),
              ),
            ],
          ),
        );
      }
      if (grokReadyMessage != null && grokReadyMessage!.isNotEmpty) {
        return _banner(
          accent: const Color(0xFFF59E0B),
          icon: Icons.check_circle_outline,
          child: Text(
            grokReadyMessage!,
            style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFFD8DCE8)),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (missingLabels.isEmpty) return const SizedBox.shrink();

    return _banner(
      accent: const Color(0xFFEF4444),
      icon: Icons.edit_note_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFFD8DCE8)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: missingLabels
                .map(
                  (label) => Chip(
                    label: Text(label),
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.12),
                    side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.35)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _banner({
    required Color accent,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}