import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/synopsis_filename.dart';
import 'package:evolve/services/synopsis_html_builder.dart';
import 'package:evolve/services/synopsis_pdf_builder.dart';

void main() {
  test('synopsis basename slugifies topic', () {
    const input = ScenarioInput(
      topic: 'Belfast knife attack protests',
      vortexText: 'What is the chance of unrest?',
    );
    final name = synopsisBasename(input, DateTime(2026, 6, 10));
    expect(name, 'evolve-synopsis-belfast-knife-attack-protests-2026-06-10');
  });

  test('HTML builder renders headings and escapes entities', () {
    const md = '## Outcome\n\n**42%** chance & <trust>';
    final html = SynopsisHtmlBuilder.document(md, title: 'Evolve Report');
    expect(html, contains('<h1>Evolve Report</h1>'));
    expect(html, contains('<h2>Outcome</h2>'));
    expect(html, contains('<strong>42%</strong>'));
    expect(html, contains('&amp;'));
    expect(html, contains('&lt;trust&gt;'));
  });

  test('PDF builder returns non-empty bytes', () async {
    const md = '# Evolve\n\n## Part One\n\nLine one.\n\n---\n\nFooter';
    final bytes = await SynopsisPdfBuilder.build(md, title: 'Evolve Synopsis');
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}