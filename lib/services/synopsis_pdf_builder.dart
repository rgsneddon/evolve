import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renders synopsis Markdown text into a downloadable PDF.
class SynopsisPdfBuilder {
  const SynopsisPdfBuilder._();

  static Future<Uint8List> build(
    String markdown, {
    required String title,
  }) async {
    final doc = pw.Document(
      title: title,
      creator: 'Evolve Chronoflux',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 14),
          ..._blocks(markdown),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    return doc.save();
  }

  static List<pw.Widget> _blocks(String markdown) {
    final widgets = <pw.Widget>[];
    for (final line in markdown.split('\n')) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }
      if (trimmed == '---') {
        widgets.add(pw.Divider(color: PdfColors.grey400));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
            child: pw.Text(
              _strip(trimmed.substring(3)),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
        continue;
      }
      if (trimmed.startsWith('# ')) {
        widgets.add(
          pw.Text(
            _strip(trimmed.substring(2)),
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );
        continue;
      }
      if (trimmed.startsWith('### ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
            child: pw.Text(
              _strip(trimmed.substring(4)),
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
        continue;
      }
      widgets.add(
        pw.Text(
          _strip(trimmed),
          style: const pw.TextStyle(fontSize: 9.5),
        ),
      );
    }
    return widgets;
  }

  static String _strip(String text) =>
      text.replaceAll('**', '').replaceAll('*', '').trim();
}