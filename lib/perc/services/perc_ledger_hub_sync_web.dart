import 'dart:html' as html;

const _revisionKey = 'perc_perccent_ledger_rev';

void Function()? bindCrossTabSync({required void Function() onRemoteRevision}) {
  final sub = html.window.onStorage.listen((event) {
    if (event.key == _revisionKey) onRemoteRevision();
  });
  return sub.cancel;
}

void broadcastRevision() {
  html.window.localStorage[_revisionKey] =
      DateTime.now().microsecondsSinceEpoch.toString();
}