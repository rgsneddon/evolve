import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../perc/services/perc_auth.dart';
import '../data/fcg_uk_ward_moderator_registry.dart';
import 'fcg_mishi_crypto.dart';
import 'fcg_mishi_directive.dart';
import 'fcg_mishi_permission.dart';

typedef FcgMishiBridgeFileResolver = Future<File> Function();

/// Encrypted bridge file shared between Evolve and Mishi.
class FcgMishiBridgeStore {
  FcgMishiBridgeStore({FcgMishiBridgeFileResolver? fileResolver})
      : _fileResolver = fileResolver ?? _defaultFile;

  static const bridgeFileName = 'fcg_mishi_bridge.enc';

  final FcgMishiBridgeFileResolver _fileResolver;

  @visibleForTesting
  static Future<File> fileForTest(String directory) async =>
      File('$directory${Platform.pathSeparator}$bridgeFileName');

  static Future<File> _defaultFile() async {
    Directory dir;
    if (Platform.isWindows) {
      final local = Platform.environment['LOCALAPPDATA'];
      if (local != null && local.isNotEmpty) {
        dir = Directory('$local${Platform.pathSeparator}Evolve${Platform.pathSeparator}mishi');
      } else {
        final support = await getApplicationSupportDirectory();
        dir = Directory('${support.path}${Platform.pathSeparator}mishi');
      }
    } else {
      final support = await getApplicationSupportDirectory();
      dir = Directory('${support.path}${Platform.pathSeparator}mishi');
    }
    return File('${dir.path}${Platform.pathSeparator}$bridgeFileName');
  }

  Future<FcgMishiBridgeData> load() async {
    final file = await _fileResolver();
    if (!await file.exists()) return const FcgMishiBridgeData();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const FcgMishiBridgeData();
    final decoded = FcgMishiCrypto.decryptJson(raw);
    return FcgMishiBridgeData.fromJson(decoded);
  }

  Future<void> save(FcgMishiBridgeData data) async {
    final file = await _fileResolver();
    await file.parent.create(recursive: true);
    final encrypted = FcgMishiCrypto.encryptJson(data.toJson());
    await file.writeAsString(encrypted);
  }

  Future<void> upsertModeratorVerifier({
    required String username,
    required String salt,
    required String passwordHash,
  }) async {
    final data = await load();
    final key = FcgUkWardModeratorRegistry.normalize(username);
    final verifiers = Map<String, FcgMishiModeratorVerifier>.from(data.verifiers);
    verifiers[key] = FcgMishiModeratorVerifier(
      username: key,
      salt: salt,
      passwordHash: passwordHash,
      updatedAt: DateTime.now().toUtc(),
    );
    await save(data.copyWith(verifiers: verifiers));
  }

  Future<bool> verifyModeratorPassword({
    required String loginAlias,
    required String password,
  }) async {
    final username = FcgUkWardModeratorRegistry.resolveLoginAlias(loginAlias);
    if (username == null) return false;
    final data = await load();
    final verifier = data.verifiers[username];
    if (verifier == null) return false;
    return PercAuth.verifyPassword(
      password: password,
      salt: verifier.salt,
      expectedHash: verifier.passwordHash,
    );
  }

  Future<FcgMishiVoterPermission?> permissionForAddress({
    required String percAddress,
    required String forumMonth,
  }) async {
    final normalized = PercAuth.normalizeAddress(percAddress);
    final data = await load();
    for (final p in data.permissions) {
      if (p.forumMonth != forumMonth) continue;
      if (PercAuth.normalizeAddress(p.percAddress) == normalized) return p;
    }
    return null;
  }

  Future<bool> hasApprovedVotingAccess({
    required String percAddress,
    String? forumMonth,
  }) async {
    final month = forumMonth ?? fcgMishiForumMonth();
    final perm = await permissionForAddress(
      percAddress: percAddress,
      forumMonth: month,
    );
    return perm?.isApproved ?? false;
  }

  Future<FcgMishiVoterPermission> requestVotingAccess({
    required String percAddress,
    required String walletUsername,
    required String moderatorUsername,
    required String wardLabel,
    String? forumMonth,
  }) async {
    final month = forumMonth ?? fcgMishiForumMonth();
    final normalized = PercAuth.normalizeAddress(percAddress);
    final data = await load();
    final existing = data.permissions.where(
      (p) =>
          p.forumMonth == month &&
          PercAuth.normalizeAddress(p.percAddress) == normalized,
    );
    if (existing.isNotEmpty) return existing.first;

    final permission = FcgMishiVoterPermission(
      percAddress: normalized,
      walletUsername: walletUsername.trim().toLowerCase(),
      moderatorUsername: FcgUkWardModeratorRegistry.normalize(moderatorUsername),
      wardLabel: wardLabel,
      forumMonth: month,
      status: FcgMishiPermissionStatus.pending,
      requestedAt: DateTime.now().toUtc(),
    );
    await save(
      data.copyWith(permissions: [...data.permissions, permission]),
    );
    return permission;
  }

  Future<void> decidePermission({
    required String percAddress,
    required String forumMonth,
    required FcgMishiPermissionStatus status,
    required String moderatorUsername,
  }) async {
    final normalized = PercAuth.normalizeAddress(percAddress);
    final data = await load();
    final updated = data.permissions.map((p) {
      if (p.forumMonth != forumMonth) return p;
      if (PercAuth.normalizeAddress(p.percAddress) != normalized) return p;
      return p.copyWith(
        status: status,
        decidedAt: DateTime.now().toUtc(),
        decidedByModerator: FcgUkWardModeratorRegistry.normalize(moderatorUsername),
      );
    }).toList();
    await save(data.copyWith(permissions: updated));
  }

  List<FcgMishiVoterPermission> pendingForModerator(
    FcgMishiBridgeData data,
    String moderatorUsername, {
    String? forumMonth,
  }) {
    final mod = FcgUkWardModeratorRegistry.normalize(moderatorUsername);
    final month = forumMonth ?? fcgMishiForumMonth();
    return data.permissions
        .where(
          (p) =>
              p.moderatorUsername == mod &&
              p.forumMonth == month &&
              p.status == FcgMishiPermissionStatus.pending,
        )
        .toList();
  }

  Future<void> enqueueDirective(FcgMishiSessionDirective directive) async {
    final data = await load();
    await save(
      data.copyWith(directives: [...data.directives, directive]),
    );
  }

  Future<List<FcgMishiSessionDirective>> takeDirectivesForModerator(
    String moderatorUsername,
  ) async {
    final mod = FcgUkWardModeratorRegistry.normalize(moderatorUsername);
    final data = await load();
    final mine = data.directives
        .where((d) => FcgUkWardModeratorRegistry.normalize(d.moderatorUsername) == mod)
        .toList();
    if (mine.isEmpty) return const [];
    final rest = data.directives
        .where((d) => FcgUkWardModeratorRegistry.normalize(d.moderatorUsername) != mod)
        .toList();
    await save(data.copyWith(directives: rest));
    return mine;
  }

  /// Proactive grant — approves address even without a prior voter request.
  Future<void> grantVotingAccess({
    required String percAddress,
    required String moderatorUsername,
    required String wardLabel,
    String? walletUsername,
    String? forumMonth,
  }) async {
    final month = forumMonth ?? fcgMishiForumMonth();
    final normalized = PercAuth.normalizeAddress(percAddress);
    final mod = FcgUkWardModeratorRegistry.normalize(moderatorUsername);
    final data = await load();
    final updated = <FcgMishiVoterPermission>[];
    var found = false;
    for (final p in data.permissions) {
      if (p.forumMonth != month ||
          PercAuth.normalizeAddress(p.percAddress) != normalized) {
        updated.add(p);
        continue;
      }
      found = true;
      updated.add(
        p.copyWith(
          status: FcgMishiPermissionStatus.approved,
          decidedAt: DateTime.now().toUtc(),
          decidedByModerator: mod,
        ),
      );
    }
    if (!found) {
      updated.add(
        FcgMishiVoterPermission(
          percAddress: normalized,
          walletUsername: (walletUsername ?? '').trim().toLowerCase(),
          moderatorUsername: mod,
          wardLabel: wardLabel,
          forumMonth: month,
          status: FcgMishiPermissionStatus.approved,
          requestedAt: DateTime.now().toUtc(),
          decidedAt: DateTime.now().toUtc(),
          decidedByModerator: mod,
        ),
      );
    }
    await save(data.copyWith(permissions: updated));
  }
}

class FcgMishiBridgeData {
  const FcgMishiBridgeData({
    this.verifiers = const {},
    this.permissions = const [],
    this.directives = const [],
  });

  final Map<String, FcgMishiModeratorVerifier> verifiers;
  final List<FcgMishiVoterPermission> permissions;
  final List<FcgMishiSessionDirective> directives;

  FcgMishiBridgeData copyWith({
    Map<String, FcgMishiModeratorVerifier>? verifiers,
    List<FcgMishiVoterPermission>? permissions,
    List<FcgMishiSessionDirective>? directives,
  }) =>
      FcgMishiBridgeData(
        verifiers: verifiers ?? this.verifiers,
        permissions: permissions ?? this.permissions,
        directives: directives ?? this.directives,
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'verifiers': verifiers.map((k, v) => MapEntry(k, v.toJson())),
        'permissions': permissions.map((p) => p.toJson()).toList(),
        'directives': directives.map((d) => d.toJson()).toList(),
      };

  factory FcgMishiBridgeData.fromJson(Map<String, dynamic> json) {
    final rawVerifiers = json['verifiers'] as Map<String, dynamic>? ?? {};
    final verifiers = <String, FcgMishiModeratorVerifier>{};
    for (final entry in rawVerifiers.entries) {
      verifiers[entry.key] = FcgMishiModeratorVerifier.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }
    final rawPerms = json['permissions'] as List<dynamic>? ?? [];
    final permissions = rawPerms
        .map((e) => FcgMishiVoterPermission.fromJson(e as Map<String, dynamic>))
        .toList();
    final rawDirs = json['directives'] as List<dynamic>? ?? [];
    final directives = rawDirs
        .map((e) => FcgMishiSessionDirective.fromJson(e as Map<String, dynamic>))
        .toList();
    return FcgMishiBridgeData(
      verifiers: verifiers,
      permissions: permissions,
      directives: directives,
    );
  }
}