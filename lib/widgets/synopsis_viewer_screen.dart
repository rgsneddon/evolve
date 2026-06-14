import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart';

/// Full synopsis view — in-app browser on desktop/mobile; companion to web tab.
class SynopsisViewerScreen extends StatelessWidget {
  const SynopsisViewerScreen({
    super.key,
    required this.markdown,
    required this.title,
  });

  final String markdown;
  final String title;

  @override
  Widget build(BuildContext context) {
    final lines = markdown.split('\n');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12182A),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: markdown));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Synopsis copied')),
              );
            },
          ),
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open tab again',
              onPressed: () {
                // Re-open handled by delivery layer on first open; copy HTML hint only.
                Clipboard.setData(ClipboardData(text: markdown));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Synopsis copied — paste into a new tab if needed'),
                  ),
                );
              },
            ),
        ],
      ),
      body: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: SelectableText.rich(
            TextSpan(children: _spans(lines)),
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Color(0xFFB8BFD0),
            ),
          ),
        ),
      ),
    );
  }

  List<TextSpan> _spans(List<String> lines) {
    final spans = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      spans.add(_lineSpan(lines[i]));
    }
    return spans;
  }

  TextSpan _lineSpan(String line) {
    if (line.startsWith('## ')) {
      return TextSpan(
        text: line.substring(3),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF00D9C0),
          fontSize: 14,
        ),
      );
    }
    if (line.startsWith('# ')) {
      return TextSpan(
        text: line.substring(2),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF00D9C0),
          fontSize: 16,
        ),
      );
    }
    if (line.startsWith('### ')) {
      return TextSpan(
        text: line.substring(4),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFFB8B5FF),
        ),
      );
    }
    if (line.trim() == '---') {
      return const TextSpan(
        text: '────────────────────────',
        style: TextStyle(color: Color(0xFF3A4256)),
      );
    }
    return TextSpan(
      text: line.replaceAll('**', ''),
      style: const TextStyle(color: Color(0xFFB8BFD0)),
    );
  }
}