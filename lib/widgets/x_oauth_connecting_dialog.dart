import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/grok_session.dart';
import '../services/grok_auth_client.dart';
import '../services/grok_oauth_launcher.dart';

/// Opens X OAuth in the browser and dismisses itself when the proxy session is ready.
class XOAuthConnectingDialog extends StatefulWidget {
  const XOAuthConnectingDialog({
    super.key,
    required this.authorize,
    required this.redirectUri,
    this.clientId = '',
    required this.sessionFuture,
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.onFinished,
    this.useMobileAuth = false,
    this.redirectHint = '',
  });

  final Uri authorize;
  final String redirectUri;
  final String clientId;
  final Future<GrokSession> sessionFuture;
  final bool useMobileAuth;
  final String title;
  final String body;
  final String redirectHint;
  final String cancelLabel;
  final void Function(GrokSession session, OAuthLaunchHandle? tab) onFinished;

  @override
  State<XOAuthConnectingDialog> createState() => _XOAuthConnectingDialogState();
}

class _XOAuthConnectingDialogState extends State<XOAuthConnectingDialog> {
  OAuthLaunchHandle? _tab;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchBrowser());
    unawaited(widget.sessionFuture.then(_complete));
  }

  Future<void> _launchBrowser() async {
    if (widget.useMobileAuth) return;
    final handle = GrokOAuthLauncher.prepareTab();
    _tab = handle;
    await GrokOAuthLauncher.launch(widget.authorize, handle: handle);
  }

  void _complete(GrokSession session) {
    if (!mounted || _finished) return;
    _finished = true;
    widget.onFinished(session, _tab);
    Navigator.of(context).pop();
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    widget.onFinished(const GrokSession(), _tab);
    Navigator.of(context).pop();
  }

  Future<void> _copyText(String value, String label) async {
    final text = value.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final redirect = widget.redirectUri.trim();
    final clientId = widget.clientId.trim();
    final hint = widget.redirectHint.trim();
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.body),
            if (clientId.isNotEmpty || redirect.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (hint.isNotEmpty) Text(hint),
              if (clientId.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Client ID (must match console.x.com):',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                SelectableText(
                  clientId,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _copyText(clientId, 'Client ID'),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Client ID'),
                  ),
                ),
              ],
              if (redirect.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Callback URL:',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                SelectableText(
                  redirect,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _copyText(redirect, 'Callback URL'),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy callback URL'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _cancel,
            child: Text(widget.cancelLabel),
          ),
        ],
      ),
    );
  }
}