import 'package:flutter/material.dart';

class ConstructMeta {
  const ConstructMeta({
    required this.key,
    required this.name,
    required this.symbol,
    required this.color,
    required this.hint,
  });

  final String key;
  final String name;
  final String symbol;
  final Color color;
  final String hint;

  static const all = [
    ConstructMeta(
      key: 'vortex',
      name: 'Vortex',
      symbol: 'ω',
      color: Color(0xFF6C63FF),
      hint: 'ω circulation relative to your posed question — elite framing, authority compression…',
    ),
    ConstructMeta(
      key: 'shear',
      name: 'Shear',
      symbol: 'σ',
      color: Color(0xFFE74C3C),
      hint: 'Bias — polarized framing, grievance, two-tier perception…',
    ),
    ConstructMeta(
      key: 'resistance',
      name: 'Resistance',
      symbol: 'Iτ',
      color: Color(0xFFF39C12),
      hint: 'Opposing bias — institutional inertia, skepticism…',
    ),
    ConstructMeta(
      key: 'flow',
      name: 'Flow',
      symbol: 'Jμ',
      color: Color(0xFF00D9C0),
      hint: 'Nuances — trust transport, covariant continuity…',
    ),
  ];
}