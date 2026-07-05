import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Obfuscates account identities on public network and explorer surfaces.
class PercAccountPrivacy {
  const PercAccountPrivacy._();

  static const int aliasLength = 5;
  static const String _aliasChars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  static const String _privacySalt = 'evolve-perc-account-privacy-v1';

  static const Set<String> _usernameFieldKeys = {
    'username',
    'sessionUsername',
    'fromUsername',
    'toUsername',
    'triggerUsername',
    'from',
    'to',
    'launchedBy',
  };

  static const Set<String> _secretFieldKeys = {
    'password',
    'passwordHash',
    'salt',
    'passwordSet',
  };

  /// Deterministic five-character alias for a username.
  static String obfuscateUsername(String username) {
    final raw = username.trim();
    if (raw.isEmpty) return '';
    final digest = Hmac(sha256, utf8.encode(_privacySalt))
        .convert(utf8.encode(raw))
        .bytes;
    final buffer = StringBuffer();
    for (var i = 0; i < aliasLength; i++) {
      buffer.write(_aliasChars[digest[i] % _aliasChars.length]);
    }
    return buffer.toString();
  }

  /// Display name for another user's username in wallet UI.
  static String publicDisplayName(
    String? username, {
    String? viewerUsername,
  }) {
    if (username == null || username.trim().isEmpty) return '';
    if (viewerUsername != null &&
        viewerUsername.trim().toLowerCase() == username.trim().toLowerCase()) {
      return username;
    }
    return obfuscateUsername(username);
  }

  static String peerKeyForAddress(String address) =>
      '_addr_${address.trim().toLowerCase()}';

  static Map<String, dynamic> sanitizeLedgerForPublic(
    Map<String, dynamic> ledger,
  ) {
    final out = Map<String, dynamic>.from(ledger);
    final accountsRaw = out['accounts'];
    if (accountsRaw is Map) {
      final sanitizedAccounts = <String, dynamic>{};
      for (final entry in accountsRaw.entries) {
        final accountKey = entry.key.toString();
        final accountValue = entry.value;
        if (accountValue is! Map) continue;
        final alias = obfuscateUsername(accountKey);
        final clean = Map<String, dynamic>.from(accountValue);
        for (final secret in _secretFieldKeys) {
          clean.remove(secret);
        }
        if (clean['username'] is String) {
          clean['username'] = obfuscateUsername(clean['username'] as String);
        }
        if (clean['transactions'] is List) {
          clean['transactions'] = _sanitizeTransactions(
            clean['transactions'] as List,
          );
        }
        sanitizedAccounts[alias] = clean;
      }
      out['accounts'] = sanitizedAccounts;
    }

    if (out['sessionUsername'] is String) {
      out['sessionUsername'] =
          obfuscateUsername(out['sessionUsername'] as String);
    }

    final blocks = out['blocks'];
    if (blocks is List) {
      out['blocks'] = blocks.map((block) {
        if (block is! Map) return block;
        final clean = Map<String, dynamic>.from(block);
        if (clean['triggerUsername'] is String) {
          clean['triggerUsername'] =
              obfuscateUsername(clean['triggerUsername'] as String);
        }
        if (clean['transactions'] is List) {
          clean['transactions'] = _sanitizeTransactions(
            clean['transactions'] as List,
          );
        }
        return clean;
      }).toList(growable: false);
    }

    final proposals = out['wardProposals'];
    if (proposals is List) {
      out['wardProposals'] = proposals.map((proposal) {
        if (proposal is! Map) return proposal;
        final clean = Map<String, dynamic>.from(proposal);
        if (clean['proposerUsername'] is String) {
          clean['proposerUsername'] =
              obfuscateUsername(clean['proposerUsername'] as String);
        }
        return clean;
      }).toList(growable: false);
    }

    final ballots = out['wardBallots'];
    if (ballots is List) {
      out['wardBallots'] = ballots.map((ballot) {
        if (ballot is! Map) return ballot;
        final clean = Map<String, dynamic>.from(ballot);
        if (clean['voterUsername'] is String) {
          clean['voterUsername'] =
              obfuscateUsername(clean['voterUsername'] as String);
        }
        return clean;
      }).toList(growable: false);
    }

    return out;
  }

  static List<dynamic> _sanitizeTransactions(List<dynamic> txs) {
    return txs.map((tx) {
      if (tx is! Map) return tx;
      final clean = Map<String, dynamic>.from(tx);
      for (final secret in _secretFieldKeys) {
        clean.remove(secret);
      }
      for (final key in _usernameFieldKeys) {
        final value = clean[key];
        if (value is String && value.isNotEmpty) {
          clean[key] = obfuscateUsername(value);
        }
      }
      return clean;
    }).toList(growable: false);
  }
}