import 'package:flutter/material.dart';

class ConclusionBlock extends StatelessWidget {
  const ConclusionBlock({
    super.key,
    required this.text,
    this.accentColor = const Color(0xFF00D9C0),
  });

  final String text;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withOpacity(0.35)),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
      ),
    );
  }
}

class ExplainerCard extends StatelessWidget {
  const ExplainerCard({
    super.key,
    required this.title,
    required this.body,
    this.bullets = const [],
    this.accentColor = const Color(0xFF6C63FF),
  });

  final String title;
  final String body;
  final List<String> bullets;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            body,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: Color(0xFF9BA3B8),
            ),
          ),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(
                            fontSize: 12, color: accentColor.withOpacity(0.8))),
                    Expanded(
                      child: SelectableText(
                        b,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: Color(0xFF8B93A8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}