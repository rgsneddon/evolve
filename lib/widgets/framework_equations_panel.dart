import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/framework_spec.dart';

class FrameworkEquationsPanel extends StatefulWidget {
  const FrameworkEquationsPanel({super.key});

  @override
  State<FrameworkEquationsPanel> createState() => _FrameworkEquationsPanelState();
}

class _FrameworkEquationsPanelState extends State<FrameworkEquationsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF9BA3B8)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Evolve framework equations (from article)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  if (_expanded)
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: FrameworkSpec.fullReference()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Equations copied')),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Article: Social Science Using the Chronoflux Framework & Social Cohesion Calculations',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
                  ),
                  const SizedBox(height: 12),
                  _section('Rules', FrameworkSpec.rules),
                  _section('PART ONE', FrameworkSpec.partOneEquations),
                  _section('PART TWO', FrameworkSpec.partTwoEquations),
                  _section('THE CONTINUUM', FrameworkSpec.continuumEquations),
                  _section('PART THREE', FrameworkSpec.partThreeEquations),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Color(0xFFB8B5FF))),
          const SizedBox(height: 6),
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $e',
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.45, color: Color(0xFFB8BFD0))),
            ),
          ),
        ],
      ),
    );
  }
}