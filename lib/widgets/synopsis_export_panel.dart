import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/analysis_mode.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../services/synopsis_delivery.dart';
import '../services/synopsis_exporter.dart';
import '../services/synopsis_filename.dart';

class SynopsisExportPanel extends StatefulWidget {
  const SynopsisExportPanel({
    super.key,
    required this.input,
    required this.result,
    required this.mode,
    required this.locale,
  });

  final ScenarioInput input;
  final EvolveResult result;
  final AnalysisMode mode;
  final LocaleConfig locale;

  @override
  State<SynopsisExportPanel> createState() => _SynopsisExportPanelState();
}

class _SynopsisExportPanelState extends State<SynopsisExportPanel> {
  static const _exporter = SynopsisExporter();
  bool _exportingPdf = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context.watch<LocaleProvider>().config);
    final compact = MediaQuery.sizeOf(context).width < 520;
    final stamp = DateTime.now();
    final synopsis = _exporter.export(
      input: widget.input,
      result: widget.result,
      mode: widget.mode,
      locale: widget.locale,
      createdAt: stamp,
    );
    final basename = synopsisBasename(widget.input, stamp);
    final title = strings.t('synopsis_export_title');

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, color: Color(0xFF00D9C0)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.t('synopsis_export_hint'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF9BA3B8),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E2433)),
              ),
              child: SelectableText(
                _preview(synopsis),
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: Color(0xFF8B93A8),
                  fontFamily: 'monospace',
                ),
                maxLines: 8,
              ),
            ),
            const SizedBox(height: 14),
            if (compact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _exportButtons(
                  context,
                  strings: strings,
                  synopsis: synopsis,
                  basename: basename,
                  title: title,
                ),
              )
            else
              Row(
                children: _exportButtons(
                  context,
                  strings: strings,
                  synopsis: synopsis,
                  basename: basename,
                  title: title,
                  expanded: true,
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _copySynopsis(
                  context,
                  synopsis,
                  strings.t('synopsis_copied'),
                ),
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: Text(strings.t('synopsis_copy_button')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _exportButtons(
    BuildContext context, {
    required dynamic strings,
    required String synopsis,
    required String basename,
    required String title,
    bool expanded = false,
  }) {
    Widget wrap(Widget child) =>
        expanded ? Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child)) : child;

    final pdf = wrap(
      SizedBox(
        height: 44,
        child: OutlinedButton.icon(
          onPressed: _exportingPdf
              ? null
              : () => _exportPdf(context, synopsis, basename, title, strings),
          icon: _exportingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(strings.t('synopsis_export_pdf')),
        ),
      ),
    );

    final text = wrap(
      SizedBox(
        height: 44,
        child: OutlinedButton.icon(
          onPressed: () => _exportText(context, synopsis, basename, strings),
          icon: const Icon(Icons.article_outlined, size: 18),
          label: Text(strings.t('synopsis_export_text')),
        ),
      ),
    );

    final browser = wrap(
      SizedBox(
        height: 44,
        child: OutlinedButton.icon(
          onPressed: () => _openBrowser(context, synopsis, title),
          icon: const Icon(Icons.open_in_browser, size: 18),
          label: Text(strings.t('synopsis_export_browser')),
        ),
      ),
    );

    if (expanded) {
      return [pdf, text, browser];
    }
    return [
      text,
      const SizedBox(height: 8),
      browser,
      const SizedBox(height: 8),
      pdf,
    ];
  }

  String _preview(String synopsis) {
    final lines = synopsis.split('\n');
    if (lines.length <= 10) return synopsis;
    return '${lines.take(10).join('\n')}\n…';
  }

  Future<void> _exportText(
    BuildContext context,
    String synopsis,
    String basename,
    dynamic strings,
  ) async {
    final ok = await SynopsisDelivery.exportTextFile(
      text: synopsis,
      basename: basename,
    );
    if (!context.mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.t('synopsis_saved_text'))),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    String synopsis,
    String basename,
    String title,
    dynamic strings,
  ) async {
    setState(() => _exportingPdf = true);
    try {
      final ok = await SynopsisDelivery.exportPdfFile(
        text: synopsis,
        title: title,
        basename: basename,
      );
      if (!context.mounted || !ok) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('synopsis_saved_pdf'))),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _openBrowser(
    BuildContext context,
    String synopsis,
    String title,
  ) async {
    await SynopsisDelivery.openInBrowser(
      context: context,
      markdown: synopsis,
      title: title,
    );
  }

  void _copySynopsis(BuildContext context, String synopsis, String message) {
    Clipboard.setData(ClipboardData(text: synopsis));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}