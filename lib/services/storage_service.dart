// services/storage_service.dart
//
// VaultX — Secure Storage
// iOS Keychain / Android Keystore via flutter_secure_storage.
// Storage keys intentionally kept as fortress_vault_* for backwards compatibility
// with any existing installs migrating from the previous version.

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/vault_entry.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const _keyReal   = 'fortress_vault_real';
  static const _keyDummy  = 'fortress_vault_dummy';
  static const _keyConfig = 'fortress_vault_config_v2';

  // ── Low-level ───────────────────────────────────────────────────────────────
  static Future<String?> read(String key) async {
    try { return await _storage.read(key: key); }
    catch (_) { return null; }
  }

  static Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  static Future<void> delete(String key) async {
    try { await _storage.delete(key: key); } catch (_) {}
  }

  // ── Vault read/write ────────────────────────────────────────────────────────
  static Future<String?> readRealVault()  => read(_keyReal);
  static Future<String?> readDummyVault() => read(_keyDummy);

  static Future<void> writeRealVault(String encrypted)  => write(_keyReal,  encrypted);
  static Future<void> writeDummyVault(String encrypted) => write(_keyDummy, encrypted);

  // ── Config ──────────────────────────────────────────────────────────────────
  static Future<VaultConfig> loadConfig() async {
    final raw = await read(_keyConfig);
    if (raw == null) return VaultConfig.defaultConfig;
    try {
      return VaultConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return VaultConfig.defaultConfig;
    }
  }

  static Future<void> saveConfig(VaultConfig config) =>
      write(_keyConfig, jsonEncode(config.toJson()));

  // ── Lockout thresholds ──────────────────────────────────────────────────────
  // 3 attempts → 30 s │ 5 → 5 min │ 7 → 1 hr │ 10+ → 24 hr
  static const _lockoutThresholds = {3: 30, 5: 300, 7: 3600, 10: 86400};

  static Future<VaultConfig> recordFailedAttempt(VaultConfig config) async {
    final attempts   = config.failedAttempts + 1;
    final lockSec    = _lockoutThresholds[attempts] ?? (attempts >= 10 ? 86400 : 0);
    final lockedUntil = lockSec > 0
        ? DateTime.now().millisecondsSinceEpoch + lockSec * 1000
        : null;
    final updated = config.copyWith(
      failedAttempts: attempts,
      lockedUntil: lockedUntil,
    );
    await saveConfig(updated);
    return updated;
  }

  static Future<VaultConfig> recordSuccessfulUnlock(VaultConfig config) async {
    final updated = config.copyWith(
      failedAttempts: 0,
      clearLockedUntil: true,
    );
    await saveConfig(updated);
    return updated;
  }
}
