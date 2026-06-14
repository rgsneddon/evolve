import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LicenseAttributionPanel extends StatefulWidget {
  const LicenseAttributionPanel({super.key, required this.strings});

  final dynamic strings;

  @override
  State<LicenseAttributionPanel> createState() => _LicenseAttributionPanelState();
}

class _LicenseAttributionPanelState extends State<LicenseAttributionPanel> {
  bool _expanded = false;

  Future<void> _showFullLicense() async {
    final text = await rootBundle.loadString('LICENSE');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.strings.t('license_dialog_title')),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(text, style: const TextStyle(fontSize: 12, height: 1.45)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.strings.t('grok_dialog_ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
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
                  Expanded(
                    child: Text(
                      s.t('license_panel_title'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('license_chronoflux_attribution'),
                    style: const TextStyle(fontSize: 12, height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.t('license_copyright'),
                    style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF9BA3B8)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.t('license_dual_summary'),
                    style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF9BA3B8)),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _showFullLicense,
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: Text(s.t('license_view_full')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}