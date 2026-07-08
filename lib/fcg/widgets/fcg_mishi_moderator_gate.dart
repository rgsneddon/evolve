import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../data/fcg_uk_ward_moderator_registry.dart';
import '../mishi/fcg_mishi_bridge_store.dart';

/// Moderator-only sign-in on the voting block screen — unlocks private Mishi launcher.
class FcgMishiModeratorGate extends StatefulWidget {
  const FcgMishiModeratorGate({super.key, required this.strings});

  final AppLocalizations strings;

  @override
  State<FcgMishiModeratorGate> createState() => _FcgMishiModeratorGateState();
}

class _FcgMishiModeratorGateState extends State<FcgMishiModeratorGate> {
  final _aliasController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _signedInModerator;
  String? _mishiPath;

  @override
  void dispose() {
    _aliasController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final alias = _aliasController.text.trim();
    final password = _passwordController.text;
    final username = FcgUkWardModeratorRegistry.resolveLoginAlias(alias);
    if (username == null) {
      setState(() {
        _busy = false;
        _error = widget.strings.t('fcg_mishi_gate_unknown_moderator');
      });
      return;
    }
    final store = FcgMishiBridgeStore();
    final ok = await store.verifyModeratorPassword(
      loginAlias: alias,
      password: password,
    );
    if (!ok) {
      setState(() {
        _busy = false;
        _error = widget.strings.t('fcg_mishi_gate_login_failed');
      });
      return;
    }
    _passwordController.clear();
    final path = await _resolveMishiLauncherPath();
    setState(() {
      _busy = false;
      _signedInModerator = username;
      _mishiPath = path;
    });
  }

  Future<String> _resolveMishiLauncherPath() async {
    if (!kIsWeb && Platform.isWindows) {
      final local = Platform.environment['LOCALAPPDATA'];
      if (local != null && local.isNotEmpty) {
        final candidate = '$local\\Evolve\\mishi\\mishi.exe';
        if (await File(candidate).exists()) return candidate;
        return '$local\\Evolve\\mishi';
      }
    }
    return widget.strings.t('fcg_mishi_gate_cli_hint');
  }

  Future<void> _copyMishiHint() async {
    final text = _mishiPath ?? '';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.strings.t('fcg_mishi_gate_copied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    if (_signedInModerator != null) {
      final ward =
          FcgUkWardModeratorRegistry.wardNameFor(_signedInModerator!) ??
              _signedInModerator!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.t('fcg_mishi_gate_signed_in')
                .replaceAll('{mod}', _signedInModerator!)
                .replaceAll('{ward}', ward),
            style: const TextStyle(fontSize: 13, color: Color(0xFF9BA3B8)),
          ),
          const SizedBox(height: 12),
          Text(
            s.t('fcg_mishi_gate_private_download'),
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _mishiPath ?? '',
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _copyMishiHint,
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: Text(s.t('fcg_mishi_gate_copy_path')),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Text(
          s.t('fcg_mishi_gate_title'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          s.t('fcg_mishi_gate_hint'),
          style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF9BA3B8)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _aliasController,
          decoration: InputDecoration(
            labelText: s.t('fcg_mishi_gate_alias_label'),
            isDense: true,
          ),
          autocorrect: false,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: s.t('fcg_mishi_gate_password_label'),
            isDense: true,
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          obscureText: _obscure,
          onSubmitted: (_) => _busy ? null : _signIn(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _signIn,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(s.t('fcg_mishi_gate_sign_in')),
        ),
      ],
    );
  }
}