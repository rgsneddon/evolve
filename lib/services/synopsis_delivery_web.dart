import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/synopsis_viewer_screen.dart';
import 'synopsis_html_builder.dart';
import 'synopsis_pdf_builder.dart';

/// Web synopsis export — blob downloads and new browser tab.
class SynopsisDelivery {
  const SynopsisDelivery._();

  static Future<bool> exportTextFile({
    required String text,
    required String basename,
  }) async {
    _downloadBytes(
      Uint8List.fromList(utf8.encode(text)),
      '$basename.md',
      'text/markdown;charset=utf-8',
    );
    return true;
  }

  static Future<bool> exportPdfFile({
    required String text,
    required String title,
    required String basename,
  }) async {
    final bytes = await SynopsisPdfBuilder.build(text, title: title);
    _downloadBytes(bytes, '$basename.pdf', 'application/pdf');
    return true;
  }

  static Future<void> openInBrowser({
    required BuildContext context,
    required String markdown,
    required String title,
  }) async {
    final doc = SynopsisHtmlBuilder.document(markdown, title: title);
    final blob = html.Blob([doc], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    html.Url.revokeObjectUrl(url);

    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SynopsisViewerScreen(
          markdown: markdown,
          title: title,
        ),
      ),
    );
  }

  static void _downloadBytes(Uint8List bytes, String filename, String mime) {
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}