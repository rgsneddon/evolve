/// Canonical seed-recovery network payload (ledger envelope ± Suite sealed meta).
///
/// All writers (hub [publishSeedRecoveryEnvelopes], Suite export) must use
/// [buildSeedRecoveryNetworkPayload] so a later ledger-only publish cannot
/// clobber sealed KEYGEN/licence meta on the same fingerprint.
library;

import 'dart:convert';

/// Kind marker for composite transport (ledger envelope + sealed Suite meta).
const String kSuiteSeedTransportKind = 'suite_seed_transport';

/// Decode composite transport or legacy raw ledger envelope.
///
/// Returns `(ledgerEnvelopeB64, metaBlobB64)`.
({String ledger, String? meta}) decodeSeedRecoveryTransport(String raw) {
  if (raw.isEmpty) {
    return (ledger: '', meta: null);
  }
  try {
    final decoded = utf8.decode(base64Decode(raw));
    final map = jsonDecode(decoded);
    if (map is Map && map['kind'] == kSuiteSeedTransportKind) {
      final ledger = (map['ledger'] as String? ?? '').trim();
      if (ledger.isEmpty) {
        throw FormatException('suite_seed_transport missing ledger');
      }
      final meta = map['meta'] as String?;
      return (
        ledger: ledger,
        meta: (meta != null && meta.isNotEmpty) ? meta : null,
      );
    }
  } catch (_) {
    // Not composite — treat as legacy ledger-only envelope.
  }
  return (ledger: raw, meta: null);
}

/// Encode ledger envelope + optional sealed meta into one rendezvous string.
String encodeSeedRecoveryTransport({
  required String ledgerEnvelopeB64,
  String? metaBlobB64,
}) {
  if (metaBlobB64 == null || metaBlobB64.isEmpty) {
    return ledgerEnvelopeB64;
  }
  final payload = <String, dynamic>{
    'v': 1,
    'kind': kSuiteSeedTransportKind,
    'ledger': ledgerEnvelopeB64,
    'meta': metaBlobB64,
  };
  return base64Encode(utf8.encode(jsonEncode(payload)));
}

/// Pure: build the single string PUT on `/perc/rendezvous/seed-recovery`.
///
/// - Unwraps [ledgerEnvelopeB64] if it is already composite.
/// - Prefers explicit [metaBlobB64], else meta from ledger arg, else meta from
///   [existingRemoteB64] (so hub re-publish keeps Suite KEYGEN seal).
/// - Emits composite when any meta is known; else legacy ledger-only.
String buildSeedRecoveryNetworkPayload({
  required String ledgerEnvelopeB64,
  String? metaBlobB64,
  String? existingRemoteB64,
}) {
  final fromLedger = decodeSeedRecoveryTransport(ledgerEnvelopeB64);
  final ledger = fromLedger.ledger.isNotEmpty
      ? fromLedger.ledger
      : ledgerEnvelopeB64;

  String? meta = metaBlobB64;
  if (meta == null || meta.isEmpty) {
    meta = fromLedger.meta;
  }
  if ((meta == null || meta.isEmpty) &&
      existingRemoteB64 != null &&
      existingRemoteB64.isNotEmpty) {
    meta = decodeSeedRecoveryTransport(existingRemoteB64).meta;
  }

  return encodeSeedRecoveryTransport(
    ledgerEnvelopeB64: ledger,
    metaBlobB64: meta,
  );
}
