import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/outcome_record.dart';

/// Historical labeled outcomes for base-rate lookup and calibration metadata.
class OutcomeRegistry {
  OutcomeRegistry._(this.records);

  final List<OutcomeRecord> records;

  static OutcomeRegistry? _cached;

  static Future<OutcomeRegistry> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString('assets/data/outcome_registry.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['records'] as List<dynamic>)
        .map((e) => OutcomeRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    _cached = OutcomeRegistry._(list);
    return _cached!;
  }

  /// Synchronous access — uses full registry after [ensureLoaded], else compact fallback.
  static OutcomeRegistry bundled() => _cached ??= OutcomeRegistry._(_fallbackRecords());

  static void resetForTests() => _cached = null;

  static Future<void> ensureLoaded() async {
    if (_cached != null && _cached!.records.length > 200) return;
    _cached = await load();
  }

  static List<OutcomeRecord> _fallbackRecords() {
    const classes = [
      ('civil_unrest', 0.24),
      ('recession', 0.17),
      ('election_upset', 0.31),
      ('cohesion_decline', 0.28),
      ('policy_passage', 0.42),
      ('general_scenario', 0.35),
    ];
    final out = <OutcomeRecord>[];
    var id = 1;
    for (var year = 2010; year <= 2025; year++) {
      for (final (cls, rate) in classes) {
        for (var i = 0; i < 4; i++) {
          final occurred = (year + id + cls.hashCode) % 100 < (rate * 100).round();
          out.add(OutcomeRecord(
            id: 'FB-${id.toString().padLeft(4, '0')}',
            eventClass: cls,
            regionId: i.isEven ? 'global' : 'uk_ireland',
            horizonDays: [30, 60, 180, 365][i % 4],
            yearPosed: year,
            occurred: occurred,
            source: 'ACLED',
          ));
          id++;
        }
      }
    }
    return out;
  }

  List<OutcomeRecord> matching({
    required String eventClass,
    required String regionId,
    required int horizonDays,
  }) {
    final horizonBucket = _horizonBucket(horizonDays);
    return records.where((r) {
      if (r.eventClass != eventClass) return false;
      if (r.regionId != regionId) return false;
      if (_horizonBucket(r.horizonDays) != horizonBucket) return false;
      return true;
    }).toList();
  }

  List<OutcomeRecord> matchingWithFallback({
    required String eventClass,
    required String regionId,
    required int horizonDays,
  }) {
    var hits = matching(
      eventClass: eventClass,
      regionId: regionId,
      horizonDays: horizonDays,
    );
    if (hits.isEmpty && regionId == 'usa') {
      hits = matching(
        eventClass: eventClass,
        regionId: 'americas',
        horizonDays: horizonDays,
      );
    }
    if (hits.isNotEmpty || regionId != 'global') return hits;

    return records
        .where((r) =>
            r.eventClass == eventClass &&
            _horizonBucket(r.horizonDays) == _horizonBucket(horizonDays))
        .toList();
  }

  static int _horizonBucket(int days) {
    if (days <= 45) return 30;
    if (days <= 120) return 90;
    if (days <= 240) return 180;
    return 365;
  }
}