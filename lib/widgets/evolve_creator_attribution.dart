import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

/// Linked creator / Chronoflux / Beam attribution used across wallet and license UI.
class EvolveCreatorAttribution extends StatefulWidget {
  const EvolveCreatorAttribution({
    super.key,
    required this.strings,
    this.style,
    this.linkStyle,
    this.textAlign = TextAlign.center,
  });

  final AppLocalizations strings;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextAlign textAlign;

  static const russellUrl = 'https://github.com/rgsneddon';
  static const royUrl = 'https://royherbert2.academia.edu/';
  static const beamUrl = 'https://github.com/BeamMW';

  @override
  State<EvolveCreatorAttribution> createState() => _EvolveCreatorAttributionState();
}

class _EvolveCreatorAttributionState extends State<EvolveCreatorAttribution> {
  late final TapGestureRecognizer _russellTap;
  late final TapGestureRecognizer _royTap;
  late final TapGestureRecognizer _beamTap;

  @override
  void initState() {
    super.initState();
    _russellTap = TapGestureRecognizer()
      ..onTap = () => _launch(EvolveCreatorAttribution.russellUrl);
    _royTap = TapGestureRecognizer()
      ..onTap = () => _launch(EvolveCreatorAttribution.royUrl);
    _beamTap = TapGestureRecognizer()
      ..onTap = () => _launch(EvolveCreatorAttribution.beamUrl);
  }

  @override
  void dispose() {
    _russellTap.dispose();
    _royTap.dispose();
    _beamTap.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final baseStyle = widget.style ??
        const TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: Color(0xFF7A8299),
          height: 1.4,
        );
    final linkStyle = widget.linkStyle ??
        baseStyle.copyWith(
          color: const Color(0xFF6C63FF),
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFF6C63FF),
        );

    return RichText(
      textAlign: widget.textAlign,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: strings.t('creator_attribution_prefix')),
          TextSpan(
            text: strings.t('creator_attribution_russell'),
            style: linkStyle,
            recognizer: _russellTap,
          ),
          TextSpan(text: strings.t('creator_attribution_middle')),
          TextSpan(
            text: strings.t('creator_attribution_roy'),
            style: linkStyle,
            recognizer: _royTap,
          ),
          TextSpan(text: strings.t('creator_attribution_suffix')),
          TextSpan(
            text: strings.t('creator_attribution_beam'),
            style: linkStyle,
            recognizer: _beamTap,
          ),
        ],
      ),
    );
  }
}