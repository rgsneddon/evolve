import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_localizations.dart';

/// Requests camera access before opening the PERC QR scanner.
class PercCameraPermission {
  const PercCameraPermission._();

  static Future<bool> ensureGranted(
    BuildContext context,
    AppLocalizations strings,
  ) async {
    if (kIsWeb) {
      // The browser shows its own camera permission prompt when scanning starts.
      return true;
    }

    var status = await Permission.camera.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied || status.isRestricted) {
      if (context.mounted) {
        await _showOpenSettingsDialog(context, strings);
      }
      return false;
    }

    if (!context.mounted) return false;
    final proceed = await _showRationaleDialog(context, strings);
    if (!proceed || !context.mounted) return false;

    status = await Permission.camera.request();
    if (status.isGranted) return true;

    if (!context.mounted) return false;
    if (status.isPermanentlyDenied || status.isRestricted) {
      await _showOpenSettingsDialog(context, strings);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('wallet_camera_permission_denied'))),
      );
    }
    return false;
  }

  static Future<bool> _showRationaleDialog(
    BuildContext context,
    AppLocalizations strings,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('wallet_camera_permission_title')),
        content: Text(strings.t('wallet_camera_permission_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.t('wallet_camera_permission_not_now')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.t('wallet_camera_permission_allow')),
          ),
        ],
      ),
    );
    return result == true;
  }

  static Future<void> _showOpenSettingsDialog(
    BuildContext context,
    AppLocalizations strings,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('wallet_camera_permission_title')),
        content: Text(strings.t('wallet_camera_permission_settings_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.t('wallet_camera_permission_not_now')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: Text(strings.t('wallet_camera_permission_open_settings')),
          ),
        ],
      ),
    );
  }
}