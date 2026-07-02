import 'dart:async';

import 'package:flutter/material.dart';

import '../models/grok_session.dart';
import '../services/grok_auth_client.dart';
import '../services/grok_oauth_launcher.dart';

/// Opens X OAuth in the browser and dismisses itself when the proxy session is ready.
class XOAuthConnectingDialog extends StatefulWidget {
  const XOAuthConnectingDialog({
    super.key,
    required this.authorize,
    required this.redirectUri,
    required this.sessionFuture,
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.onFinished,
    this.useMobileAuth = false,
  });

  final Uri authorize;
  final String redirectUri;
  final Future<GrokSession> sessionFuture;
  final bool useMobileAuth;
  final String title;
  final String body;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.body),
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