import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Username + password recovered after a successful biometric prompt.
class WalletBiometricCredentials {
  const WalletBiometricCredentials({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;
}

/// Android-only vault: secure storage + [LocalAuthentication] gate.
class WalletBiometricCredentialStore {
  WalletBiometricCredentialStore({
    LocalAuthentication? localAuth,
    FlutterSecureStorage? secureStorage,
    @visibleForTesting bool? androidPlatformOverride,
    @visibleForTesting Future<bool> Function(String reason)? authenticateOverride,
    @visibleForTesting Future<bool> Function()? availabilityOverride,
    @visibleForTesting Map<String, String>? memoryStorage,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _storage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _androidPlatformOverride = androidPlatformOverride,
        _authenticateOverride = authenticateOverride,
        _availabilityOverride = availabilityOverride,
        _memoryStorage = memoryStorage;

  static const _keyEnabled = 'wallet_biometric_enabled';
  static const _keyPayload = 'wallet_biometric_credentials';

  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _storage;
  final bool? _androidPlatformOverride;
  final Future<bool> Function(String reason)? _authenticateOverride;
  final Future<bool> Function()? _availabilityOverride;
  final Map<String, String>? _memoryStorage;

  bool get isAndroidPlatform {
    if (_androidPlatformOverride != null) return _androidPlatformOverride!;
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Future<bool> isBiometricAvailableOnDevice() async {
    if (!isAndroidPlatform) return false;
    if (_availabilityOverride != null) return _availabilityOverride!();
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return canCheck || supported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasStoredCredentials() async {
    if (!isAndroidPlatform) return false;
    final enabled = await _read(_keyEnabled);
    return enabled == 'true';
  }

  Future<String?> storedUsername() async {
    if (!await hasStoredCredentials()) return null;
    final raw = await _read(_keyPayload);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['username'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveCredentials({
    required String username,
    required String password,
  }) async {
    if (!isAndroidPlatform) return false;
    final payload = jsonEncode({
      'username': username,
      'password': password,
    });
    await _write(_keyPayload, payload);
    await _write(_keyEnabled, 'true');
    return true;
  }

  Future<WalletBiometricCredentials?> unlockWithBiometric({
    required String localizedReason,
  }) async {
    if (!isAndroidPlatform) return null;
    if (!await hasStoredCredentials()) return null;
    try {
      final ok = _authenticateOverride != null
          ? await _authenticateOverride!(localizedReason)
          : await _localAuth.authenticate(
              localizedReason: localizedReason,
              options: const AuthenticationOptions(
                stickyAuth: true,
                biometricOnly: true,
              ),
            );
      if (!ok) return null;
      final raw = await _read(_keyPayload);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final username = map['username'] as String?;
      final password = map['password'] as String?;
      if (username == null ||
          password == null ||
          username.isEmpty ||
          password.isEmpty) {
        return null;
      }
      return WalletBiometricCredentials(
        username: username,
        password: password,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCredentials() async {
    await _delete(_keyEnabled);
    await _delete(_keyPayload);
  }

  Future<String?> _read(String key) async {
    if (_memoryStorage != null) return _memoryStorage![key];
    return _storage.read(key: key);
  }

  Future<void> _write(String key, String value) async {
    if (_memoryStorage != null) {
      _memoryStorage![key] = value;
      return;
    }
    await _storage.write(key: key, value: value);
  }

  Future<void> _delete(String key) async {
    if (_memoryStorage != null) {
      _memoryStorage!.remove(key);
      return;
    }
    await _storage.delete(key: key);
  }
}