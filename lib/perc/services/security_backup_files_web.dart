import 'dart:html' as html;
import 'dart:typed_data';

Future<void> writeBackupFile(String path, Uint8List bytes) async {
  await exportBackupToDevice(suggestedName: path, bytes: bytes);
}

/// Triggers a browser download of encrypted backup bytes.
Future<bool> exportBackupToDevice({
  required String suggestedName,
  required Uint8List bytes,
}) async {
  final blob = html.Blob([bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', suggestedName)
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}