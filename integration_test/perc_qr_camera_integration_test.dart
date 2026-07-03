import 'dart:io';
import 'dart:ui' as ui;

import 'package:evolve/l10n/app_localizations.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/perc/services/perc_auth.dart';
import 'package:evolve/perc/services/perc_qr_address_parser.dart';
import 'package:evolve/perc/services/perc_qr_scanner_support.dart';
import 'package:evolve/perc/widgets/perc_address_qr_scanner_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<String> _writeTestQrPng(String data) async {
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    gapless: true,
    color: const Color(0xFF000000),
    emptyColor: const Color(0xFFFFFFFF),
  );
  final imageData = await painter.toImageData(512, format: ui.ImageByteFormat.png);
  if (imageData == null) {
    throw StateError('Failed to render test QR image');
  }
  final path =
      '${Directory.systemTemp.path}${Platform.pathSeparator}perc_wallet_qr_integration.png';
  await File(path).writeAsBytes(imageData.buffer.asUint8List());
  return path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PERC send scanner opens the device camera on mobile', (tester) async {
    if (!percQrScannerSupported) {
      // mobile_scanner has no Windows/Linux desktop plugin — verified separately.
      return;
    }

    final strings =
        AppLocalizations(const LocaleConfig(languageCode: 'en', regionId: 'uk_ireland'));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog<void>(
                context: context,
                builder: (_) => PercAddressQrScannerDialog(strings: strings),
              );
            });
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.text(strings.t('wallet_send_scan_ready')).evaluate().isNotEmpty) {
        break;
      }
      if (find.text(strings.t('wallet_send_scan_camera_error')).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(
      find.text(strings.t('wallet_send_scan_ready')),
      findsOneWidget,
      reason: 'Device camera should initialize for the wallet QR scanner popup',
    );
    expect(
      find.text(strings.t('wallet_send_scan_camera_error')),
      findsNothing,
      reason: 'Camera permission or access should not fail on this device',
    );
  });

  testWidgets('mobile_scanner decodes a PERC address QR image on mobile', (tester) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final address = PercAuth.deriveAddress('integration_camera', 'verify-salt');
    final imagePath = await _writeTestQrPng(address);

    final controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      autoStart: false,
    );
    addTearDown(controller.dispose);

    final capture = await controller.analyzeImage(imagePath);
    expect(capture, isNotNull);

    final raw = capture!.barcodes.first.rawValue;
    expect(raw, isNotNull);
    expect(PercQrAddressParser.parse(raw!), address);

    await File(imagePath).delete();
  });
}