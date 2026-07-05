import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Immutable parish-vote audit actions — append-only, never edited in place.
enum FcgAuditAction {
  sessionOpened,
  addressCommitted,
  addressCleared,
  slotReleased,
  addressReEnrolled,
  voteCast,
  voteChanged,
  narrativeLinked,
  sessionClosed,
}

extension FcgAuditActionJson on FcgAuditAction {
  String toJson() => name;

  static FcgAuditAction fromJson(String raw) =>
      FcgAuditAction.values.asNameMap()[raw] ?? FcgAuditAction.sessionOpened;
}

class FcgAuditEntry {
  const FcgAuditEntry({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.actor,
    this.slotNumber,
    this.percAddress,
    this.voteName,
    this.detail,
    this.prevHash = 'genesis',
    this.entryHash = '',
  });

  final String id;
  final DateTime timestamp;
  final FcgAuditAction action;
  final String actor;
  final int? slotNumber;
  final String? percAddress;
  final String? voteName;
  final String? detail;
  final String prevHash;
  final String entryHash;

  Map<String, dynamic> toPayload() => {
        'id': id,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'action': action.toJson(),
        'actor': actor,
        if (slotNumber != null) 'slotNumber': slotNumber,
        if (percAddress != null) 'percAddress': percAddress,
        if (voteName != null) 'vote': voteName,
        if (detail != null) 'detail': detail,
        'prevHash': prevHash,
      };

  Map<String, dynamic> toJson() => {
        ...toPayload(),
        'entryHash': entryHash,
      };

  factory FcgAuditEntry.fromJson(Map<String, dynamic> json) => FcgAuditEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
        action: FcgAuditActionJson.fromJson(json['action'] as String? ?? ''),
        actor: json['actor'] as String? ?? '',
        slotNumber: json['slotNumber'] as int?,
        percAddress: json['percAddress'] as String?,
        voteName: json['vote'] as String?,
        detail: json['detail'] as String?,
        prevHash: json['prevHash'] as String? ?? 'genesis',
        entryHash: json['entryHash'] as String? ?? '',
      );
}

/// Append-only audit chain for a parish vote session.
class FcgAuditLog {
  const FcgAuditLog({this.entries = const []});

  final List<FcgAuditEntry> entries;

  String get tipHash =>
      entries.isEmpty ? 'genesis' : entries.last.entryHash;

  bool slotHasEnrollmentHistory(int slotNumber) {
    for (final entry in entries) {
      if (entry.slotNumber != slotNumber) continue;
      switch (entry.action) {
        case FcgAuditAction.addressCommitted:
        case FcgAuditAction.addressReEnrolled:
        case FcgAuditAction.addressCleared:
        case FcgAuditAction.slotReleased:
          return true;
        default:
          break;
      }
    }
    return false;
  }

  FcgAuditLog append(FcgAuditEntry entry) {
    final payload = entry.toPayload();
    final hash = _hash(entry.prevHash, payload);
    final sealed = FcgAuditEntry(
      id: entry.id,
      timestamp: entry.timestamp,
      action: entry.action,
      actor: entry.actor,
      slotNumber: entry.slotNumber,
      percAddress: entry.percAddress,
      voteName: entry.voteName,
      detail: entry.detail,
      prevHash: entry.prevHash,
      entryHash: hash,
    );
    return FcgAuditLog(entries: [...entries, sealed]);
  }

  static FcgAuditLog fromJsonList(List<dynamic>? raw) {
    if (raw == null || raw.isEmpty) return const FcgAuditLog();
    return FcgAuditLog(
      entries: raw
          .map((e) => FcgAuditEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  List<Map<String, dynamic>> toJsonList() =>
      entries.map((e) => e.toJson()).toList(growable: false);

  static String _hash(String prevHash, Map<String, dynamic> payload) {
    final digest = sha256.convert(
      utf8.encode('$prevHash:${jsonEncode(payload)}'),
    );
    return digest.toString();
  }
}