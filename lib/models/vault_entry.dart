// models/vault_entry.dart
// Mirrors the TypeScript types from the React Native app 1-to-1.

import 'dart:ui';
import 'package:flutter/material.dart';

// ─── Entry Category ───────────────────────────────────────────────────────────

enum EntryCategory {
  password,
  bank,
  card,
  identity,
  note,
  crypto,
  ssh,
  wifi,
}

class CategoryMeta {
  final String label;
  final IconData icon;
  final Color color;
  const CategoryMeta({required this.label, required this.icon, required this.color});
}

const Map<EntryCategory, CategoryMeta> kCategoryMeta = {
  EntryCategory.password: CategoryMeta(label: 'Password',    icon: Icons.key,               color: Color(0xFF10B981)),
  EntryCategory.bank:     CategoryMeta(label: 'Bank',        icon: Icons.account_balance,   color: Color(0xFF3B82F6)),
  EntryCategory.card:     CategoryMeta(label: 'Card',        icon: Icons.credit_card,       color: Color(0xFF8B5CF6)),
  EntryCategory.identity: CategoryMeta(label: 'Identity',    icon: Icons.person,            color: Color(0xFFF59E0B)),
  EntryCategory.note:     CategoryMeta(label: 'Secure Note', icon: Icons.description,       color: Color(0xFF6B7280)),
  EntryCategory.crypto:   CategoryMeta(label: 'Crypto',      icon: Icons.currency_bitcoin,  color: Color(0xFFF97316)),
  EntryCategory.ssh:      CategoryMeta(label: 'SSH Key',     icon: Icons.terminal,          color: Color(0xFF06B6D4)),
  EntryCategory.wifi:     CategoryMeta(label: 'Wi-Fi',       icon: Icons.wifi,              color: Color(0xFF84CC16)),
};

// ─── Vault Entry ──────────────────────────────────────────────────────────────

class VaultEntry {
  final String id;
  final String title;
  final String username;
  final String password;
  final String? url;
  final String? notes;
  final EntryCategory category;
  final List<String> tags;
  final bool isFavorite;
  final String? totpSecret;
  final int? passwordChangedAt;   // unix ms
  final bool breachDetected;
  final int breachCount;           // how many times found in HIBP database
  final int? breachCheckedAt;      // unix ms — when the check was last run
  final int updatedAt;             // unix ms
  final int createdAt;             // unix ms

  const VaultEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url,
    this.notes,
    required this.category,
    this.tags = const [],
    this.isFavorite = false,
    this.totpSecret,
    this.passwordChangedAt,
    this.breachDetected = false,
    this.breachCount    = 0,
    this.breachCheckedAt,
    required this.updatedAt,
    required this.createdAt,
  });

  VaultEntry copyWith({
    String? id, String? title, String? username, String? password,
    String? url, String? notes, EntryCategory? category,
    List<String>? tags, bool? isFavorite, String? totpSecret,
    int? passwordChangedAt, bool? breachDetected,
    int? breachCount, int? breachCheckedAt,
    int? updatedAt, int? createdAt,
  }) => VaultEntry(
    id:                id                ?? this.id,
    title:             title             ?? this.title,
    username:          username          ?? this.username,
    password:          password          ?? this.password,
    url:               url               ?? this.url,
    notes:             notes             ?? this.notes,
    category:          category          ?? this.category,
    tags:              tags              ?? this.tags,
    isFavorite:        isFavorite        ?? this.isFavorite,
    totpSecret:        totpSecret        ?? this.totpSecret,
    passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
    breachDetected:    breachDetected    ?? this.breachDetected,
    breachCount:       breachCount       ?? this.breachCount,
    breachCheckedAt:   breachCheckedAt   ?? this.breachCheckedAt,
    updatedAt:         updatedAt         ?? this.updatedAt,
    createdAt:         createdAt         ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id':                id,
    'title':             title,
    'username':          username,
    'password':          password,
    'url':               url,
    'notes':             notes,
    'category':          category.name,
    'tags':              tags,
    'isFavorite':        isFavorite,
    'totpSecret':        totpSecret,
    'passwordChangedAt': passwordChangedAt,
    'breachDetected':    breachDetected,
    'breachCount':       breachCount,
    'breachCheckedAt':   breachCheckedAt,
    'updatedAt':         updatedAt,
    'createdAt':         createdAt,
  };

  factory VaultEntry.fromJson(Map<String, dynamic> j) => VaultEntry(
    id:                j['id']                as String,
    title:             j['title']             as String,
    username:          j['username']          as String? ?? '',
    password:          j['password']          as String? ?? '',
    url:               j['url']               as String?,
    notes:             j['notes']             as String?,
    category:          EntryCategory.values.firstWhere(
                         (e) => e.name == j['category'],
                         orElse: () => EntryCategory.password),
    tags:              (j['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    isFavorite:        j['isFavorite']        as bool?   ?? false,
    totpSecret:        j['totpSecret']        as String?,
    passwordChangedAt: j['passwordChangedAt'] as int?,
    breachDetected:    j['breachDetected']    as bool?   ?? false,
    breachCount:       j['breachCount']       as int?    ?? 0,
    breachCheckedAt:   j['breachCheckedAt']   as int?,
    updatedAt:         j['updatedAt']         as int,
    createdAt:         j['createdAt']         as int,
  );
}

// ─── Vault Config ─────────────────────────────────────────────────────────────

class VaultConfig {
  final bool useBiometrics;
  final int autoLockSeconds;
  final int clipboardClearSeconds;
  final bool screenshotProtection;
  final int failedAttempts;
  final int? lockedUntil;         // unix ms

  const VaultConfig({
    this.useBiometrics        = false,
    this.autoLockSeconds      = 300,
    this.clipboardClearSeconds= 30,
    this.screenshotProtection = true,
    this.failedAttempts       = 0,
    this.lockedUntil,
  });

  static const defaultConfig = VaultConfig();

  VaultConfig copyWith({
    bool? useBiometrics, int? autoLockSeconds, int? clipboardClearSeconds,
    bool? screenshotProtection, int? failedAttempts, int? lockedUntil,
    bool clearLockedUntil = false,
  }) => VaultConfig(
    useBiometrics:         useBiometrics         ?? this.useBiometrics,
    autoLockSeconds:       autoLockSeconds        ?? this.autoLockSeconds,
    clipboardClearSeconds: clipboardClearSeconds  ?? this.clipboardClearSeconds,
    screenshotProtection:  screenshotProtection   ?? this.screenshotProtection,
    failedAttempts:        failedAttempts         ?? this.failedAttempts,
    lockedUntil:           clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
  );

  Map<String, dynamic> toJson() => {
    'useBiometrics':         useBiometrics,
    'autoLockSeconds':       autoLockSeconds,
    'clipboardClearSeconds': clipboardClearSeconds,
    'screenshotProtection':  screenshotProtection,
    'failedAttempts':        failedAttempts,
    'lockedUntil':           lockedUntil,
  };

  factory VaultConfig.fromJson(Map<String, dynamic> j) => VaultConfig(
    useBiometrics:         j['useBiometrics']         as bool?  ?? false,
    autoLockSeconds:       j['autoLockSeconds']        as int?   ?? 300,
    clipboardClearSeconds: j['clipboardClearSeconds']  as int?   ?? 30,
    screenshotProtection:  j['screenshotProtection']   as bool?  ?? true,
    failedAttempts:        j['failedAttempts']         as int?   ?? 0,
    lockedUntil:           j['lockedUntil']            as int?,
  );

  int get lockoutSecondsRemaining {
    if (lockedUntil == null) return 0;
    final rem = ((lockedUntil! - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    return rem < 0 ? 0 : rem;
  }
}

// ─── Vault State ──────────────────────────────────────────────────────────────

class VaultState {
  final List<VaultEntry> entries;
  final int? lastUnlocked;
  final int version;

  const VaultState({required this.entries, this.lastUnlocked, this.version = 2});

  Map<String, dynamic> toJson() => {
    'entries':      entries.map((e) => e.toJson()).toList(),
    'lastUnlocked': lastUnlocked,
    'version':      version,
  };

  factory VaultState.fromJson(Map<String, dynamic> j) => VaultState(
    entries:      (j['entries'] as List<dynamic>)
                    .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
                    .toList(),
    lastUnlocked: j['lastUnlocked'] as int?,
    version:      j['version']      as int? ?? 1,
  );
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, error }
enum ActiveTab  { vault, generator, settings }
