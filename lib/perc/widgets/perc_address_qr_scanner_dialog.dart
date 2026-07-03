import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/app_localizations.dart';
import '../services/perc_qr_address_parser.dart';

/// Camera QR scanner popup — returns a PERC address when a valid code is read.
class PercAddressQrScannerDialog extends StatefulWidget {
  const PercAddressQrScannerDialog({super.key, required this.strings});

  final AppLocalizations strings;

  @override
  State<PercAddressQrScannerDialog> createState() =>
      _PercAddressQrScannerDialogState();
}

class _PercAddressQrScannerDialogState extends State<PercAddressQrScannerDialog> {
  late final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  var _handled = false;
  String? _lastError;
  var _cameraReady = false;
  var _cameraFailed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScannerState);
  }

  void _onScannerState() {
    if (!mounted) return;
    final state = _controller.value;
    setState(() {
      _cameraReady = state.isRunning && state.hasCameraPermission;
      _cameraFailed =
          state.error != null || (state.isInitialized && !state.hasCameraPermission);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onScannerState);
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      final address = PercQrAddressParser.parse(raw);
      if (address == null) {
        if (mounted) setState(() => _lastError = widget.strings.t('wallet_send_scan_invalid'));
        continue;
      }
      _handled = true;
      _controller.stop();
      if (mounted) Navigator.of(context).pop(address);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: const Color(0xFF12151C),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.strings.t('wallet_send_scan_title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.strings.t('wallet_send_scan_body'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                        placeholderBuilder: (_) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        errorBuilder: (context, error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              widget.strings.t('wallet_send_scan_camera_error'),
                              style: const TextStyle(color: Color(0xFFE57373)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF6EC1FF), width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_cameraReady || _cameraFailed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _cameraFailed
                      ? widget.strings.t('wallet_send_scan_camera_error')
                      : widget.strings.t('wallet_send_scan_ready'),
                  style: TextStyle(
                    fontSize: 12,
                    color: _cameraReady
                        ? const Color(0xFF7BC67E)
                        : const Color(0xFFE57373),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_lastError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _lastError!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFE57373)),
                  textAlign: TextAlign.center,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(widget.strings.t('wallet_send_scan_cancel')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}