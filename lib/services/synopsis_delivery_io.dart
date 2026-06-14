import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../widgets/synopsis_viewer_screen.dart';
import 'synopsis_pdf_builder.dart';

/// Desktop / mobile synopsis export — save dialog + in-app browser view.
class SynopsisDelivery {
  const SynopsisDelivery._();

  static Future<bool> exportTextFile({
    required String text,
    required String basename,
  }) async {
    final location = await getSaveLocation(
      suggestedName: '$basename.md',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Markdown', extensions: ['md', 'txt']),
      ],
    );
    if (location == null) return false;
    await File(location.path).writeAsString(text);
    return true;
  }

  static Future<bool> exportPdfFile({
    required String text,
    required String title,
    required String basename,
  }) async {
    final bytes = await SynopsisPdfBuilder.build(text, title: title);
    final location = await getSaveLocation(
      suggestedName: '$basename.pdf',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (location == null) return false;
    await File(location.path).writeAsBytes(bytes);
    return true;
  }

  static Future<void> openInBrowser({
    required BuildContext context,
    required String markdown,
    required String title,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SynopsisViewerScreen(
          markdown: markdown,
          title: title,
        ),
      ),
    );
  }
}