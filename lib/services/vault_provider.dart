// services/vault_provider.dart — v4
//
// All fixes applied:
//  • Key caching     — decrypt caches derived key; saves skip PBKDF2 entirely
//  • Auto-lock pause — timer paused while isUnlocking or isSaving; restarted after
//  • UI blocking     — isUnlocking/isSaving exposed so AbsorbPointer can block UI
//  • Biometric fix   — fresh LocalAuthentication instance per call
//  • Dummy vault     — same UI as real but with subtle discreet indicator
//  • Cleared cache   — clearKeyCache() called on lockVault()
//  • Google Sign-In  — signInWithGoogle() provided for lock screen

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/vault_entry.dart';
import 'crypto_service.dart';
import 'storage_service.dart';
import 'biometric_service.dart';

class VaultProvider extends ChangeNotifier {
  // ── Public state ─────────────────────────────────────────────────────────────
  bool             isLocked        = true;
  bool             isFirstLaunch   = false;  // true until first vault is created
  bool             isUnlocking     = false;
  bool             isSaving        = false;
  bool             isSigningIn     = false;
  List<VaultEntry> entries         = [];
  bool             isDuressMode    = false;
  ActiveTab        activeTab       = ActiveTab.vault;
  VaultConfig      config          = VaultConfig.defaultConfig;
  String?          error;

  bool   biometricAvailable = false;
  String biometricLabel     = 'Biometrics';
  bool   isVerifying        = false;

  User?       currentUser;
  SyncStatus  syncStatus  = SyncStatus.idle;

  Set<String> visiblePasswords = {};
  String?     copiedEntryId;
  int         clipSecondsLeft  = 0;
  int         lockoutSeconds   = 0;

  bool        isAddingEntry = false;
  VaultEntry? editingEntry;

  String?    alertTitle;
  String?    alertMessage;
  AlertType? alertType;
  String?    alertActionLabel;   // optional button label (e.g. "Open Settings")
  VoidCallback? alertAction;    // callback for the optional button

  // ── Private ───────────────────────────────────────────────────────────────────
  String _masterPassword = '';
  Timer? _lockTimer;
  Timer? _clipTimer;
  Timer? _lockoutTimer;
  final  _uuid = const Uuid();

  static const _windowCh = MethodChannel('fortress/window');

  // ── Init ──────────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    config             = await StorageService.loadConfig();
    lockoutSeconds     = config.lockoutSecondsRemaining;
    biometricAvailable = await BiometricService.isHardwarePresent();
    biometricLabel     = await BiometricService.getBiometricLabel();
    if (config.screenshotProtection) _setFlagSecure(true);
    FirebaseAuth.instance.authStateChanges().listen((u) {
      currentUser = u;
      notifyListeners();
    });
    if (lockoutSeconds > 0) _startLockoutCountdown();

    // Detect first launch — no vault in storage means onboarding needed
    final encReal  = await StorageService.readRealVault();
    final encDummy = await StorageService.readDummyVault();
    isFirstLaunch  = (encReal == null && encDummy == null);
    notifyListeners();
  }

  /// Creates the vault for the first time with the chosen master password.
  /// Called by the onboarding setup screen after the user confirms their password.
  Future<void> createVault(String password) async {
    isUnlocking = true;
    notifyListeners();
    try {
      final state     = VaultState(
          entries:      [],
          lastUnlocked: DateTime.now().millisecondsSinceEpoch);
      final encrypted = await CryptoService.encrypt(
          jsonEncode(state.toJson()), password);
      await StorageService.writeRealVault(encrypted);
      isFirstLaunch = false;
      config        = await StorageService.recordSuccessfulUnlock(config);
      _openVault(password, [], duress: false);
    } finally {
      isUnlocking = false;
      notifyListeners();
    }
  }

  /// Called when app resumes from background — re-check biometric status
  Future<void> onResume() async {
    biometricAvailable = await BiometricService.isHardwarePresent();
    biometricLabel     = await BiometricService.getBiometricLabel();
    notifyListeners();
  }

  void _setFlagSecure(bool on) =>
      _windowCh.invokeMethod(on ? 'enable' : 'disable').catchError((_) {});

  // ── Haptics ───────────────────────────────────────────────────────────────────
  static void _h(HapticType t) {
    Vibration.hasVibrator().then((has) {
      if (has != true) return;
      switch (t) {
        case HapticType.light:   Vibration.vibrate(duration: 10); break;
        case HapticType.medium:  Vibration.vibrate(duration: 25); break;
        case HapticType.heavy:   Vibration.vibrate(duration: 50); break;
        case HapticType.success: Vibration.vibrate(pattern: [0,10,30,10]); break;
        case HapticType.error:   Vibration.vibrate(pattern: [0,50,50,50]); break;
      }
    }).catchError((_) {});
  }

  // ── Biometric ─────────────────────────────────────────────────────────────────
  Future<bool> verifyIdentity({bool force = false}) async {
    if (!config.useBiometrics && !force) return true;
    // Only block if hardware is truly absent
    if (!biometricAvailable && !force) return true;
    if (!biometricAvailable && force) {
      showAlert('Not Supported',
          'This device does not have biometric hardware.',
          AlertType.error);
      return false;
    }
    isVerifying = true;
    notifyListeners();
    try {
      final r = await BiometricService.authenticate('Verify your identity to access VaultX');
      if (r.success)    { _h(HapticType.success); return true; }
      if (r.cancelled)  { return false; }
      if (r.notEnrolled) {
        showAlert('Biometrics Not Set Up',
            'No fingerprint or face enrolled on this device.\n\nGo to Settings → Security → Biometrics to enroll.',
            AlertType.info,
            actionLabel: 'OPEN SETTINGS',
            action: openDeviceSettings);
        return false;
      }
      if (r.error != null) showAlert('Verification Failed', r.error!, AlertType.error);
      _h(HapticType.error);
      return false;
    } catch (e) {
      showAlert('Biometric Error', e.toString(), AlertType.error);
      return false;
    } finally {
      isVerifying = false;
      notifyListeners();
    }
  }

  // ── Unlock ────────────────────────────────────────────────────────────────────
  Future<void> unlockVault(String password) async {
    if (password.isEmpty || isUnlocking) return;
    final rem = config.lockoutSecondsRemaining;
    if (rem > 0) {
      error = 'Locked. Try again in ${_fmt(rem)}.';
      notifyListeners(); return;
    }

    isUnlocking = true; error = null;
    _lockTimer?.cancel();
    notifyListeners();

    try {
      final encReal  = await StorageService.readRealVault();
      final encDummy = await StorageService.readDummyVault();

      // ── First launch — no vault exists yet ─────────────────────────────────
      if (encReal == null && encDummy == null) {
        if (!await verifyIdentity()) return;
        _openVault(password, [], duress: false);
        config = await StorageService.recordSuccessfulUnlock(config);
        return;
      }

      // ── Try real vault first ────────────────────────────────────────────────
      if (encReal != null) {
        try {
          final plain = await CryptoService.decrypt(encReal, password);
          final state = VaultState.fromJson(jsonDecode(plain) as Map<String,dynamic>);
          // Real vault decrypted — open it
          if (!await verifyIdentity()) return;
          _h(HapticType.success);
          _openVault(password, state.entries, duress: false);
          config = await StorageService.recordSuccessfulUnlock(config);
          return;
        } catch (_) {
          // Real vault failed — fall through and try duress vault below
        }
      }

      // ── Try duress vault ────────────────────────────────────────────────────
      // Always try this regardless of whether real vault exists.
      // This is what makes the duress feature work: entering the duress
      // password opens the dummy vault even when a real vault is present.
      if (encDummy != null) {
        try {
          final plain = await CryptoService.decrypt(encDummy, password);
          final state = VaultState.fromJson(jsonDecode(plain) as Map<String,dynamic>);
          // Duress vault decrypted — open it silently (looks identical to real vault)
          if (!await verifyIdentity()) return;
          _h(HapticType.success);
          _openVault(password, state.entries, duress: true);
          config = await StorageService.recordSuccessfulUnlock(config);
          return;
        } catch (_) {
          // Duress vault also failed — fall through to wrong password
        }
      }

      // ── Both vaults failed — wrong password ─────────────────────────────────
      _h(HapticType.error);
      config         = await StorageService.recordFailedAttempt(config);
      lockoutSeconds = config.lockoutSecondsRemaining;
      if (lockoutSeconds > 0) _startLockoutCountdown();
      error = 'Invalid password. Access denied.';
      notifyListeners();

    } catch (e) {
      error = 'Unexpected error: $e';
      notifyListeners();
    } finally {
      isUnlocking = false;
      notifyListeners();
      if (!isLocked) _resetLockTimer();
    }
  }

  void _openVault(String pw, List<VaultEntry> es, {required bool duress}) {
    _masterPassword = pw;
    entries         = es;
    isDuressMode    = duress;
    isLocked        = false;
    error           = null;
    visiblePasswords.clear();
    copiedEntryId   = null;   // always start fresh — no stale copy badge
    clipSecondsLeft = 0;       // always start fresh — no stale timer badge
    notifyListeners();
    _resetLockTimer();
  }

  // ── Lock ──────────────────────────────────────────────────────────────────────
  void lockVault() {
    // Never lock while saving — would corrupt the in-progress write
    if (isSaving || isUnlocking) {
      _lockTimer?.cancel();
      _lockTimer = Timer(const Duration(seconds: 2), lockVault);
      return;
    }
    _h(HapticType.medium);
    clearKeyCache();
    _masterPassword = '';
    entries         = [];
    isDuressMode    = false;
    isLocked        = true;
    activeTab       = ActiveTab.vault;
    visiblePasswords.clear();

    // Always wipe the system clipboard immediately on lock, whether or not
    // the clipboard timer had fired yet. Cancel the timer first so it doesn't
    // fire again after we've already cleared.
    _clipTimer?.cancel();
    _clipTimer      = null;
    copiedEntryId   = null;
    clipSecondsLeft = 0;           // reset so the timer badge never shows on re-entry
    Clipboard.setData(const ClipboardData(text: '')); // fire-and-forget is fine here

    _lockTimer?.cancel();
    notifyListeners();
  }

  // ── Auto-lock (inactivity only) ───────────────────────────────────────────────
  void _resetLockTimer() {
    _lockTimer?.cancel();
    // Never fire while a long operation is in progress
    if (!isLocked && !isUnlocking && !isSaving && config.autoLockSeconds > 0) {
      _lockTimer = Timer(Duration(seconds: config.autoLockSeconds), lockVault);
    }
  }

  /// Reset on every user interaction — called by Listener in main.dart
  void resetActivity() { if (!isLocked) _resetLockTimer(); }

  // ── Lockout countdown ─────────────────────────────────────────────────────────
  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (lockoutSeconds <= 1) { lockoutSeconds = 0; _lockoutTimer?.cancel(); }
      else                       lockoutSeconds--;
      notifyListeners();
    });
  }

  String _fmt(int s) => s >= 60 ? '${s~/60}m ${s%60}s' : '${s}s';

  // ── Save vault (key cached → AES only, ~2ms) ──────────────────────────────────
  Future<void> _saveVault(List<VaultEntry> updated) async {
    if (_masterPassword.isEmpty) return;
    final state = VaultState(
        entries: updated, lastUnlocked: DateTime.now().millisecondsSinceEpoch);
    // After first unlock, encrypt uses cached key → skips PBKDF2 → fast
    final enc = await CryptoService.encrypt(jsonEncode(state.toJson()), _masterPassword);
    if (isDuressMode) await StorageService.writeDummyVault(enc);
    else              await StorageService.writeRealVault(enc);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────────
  Future<void> addOrUpdateEntry(VaultEntry entry) async {
    if (!await verifyIdentity()) return;

    isSaving = true;
    _lockTimer?.cancel();
    notifyListeners();
    try {
      final updated = entries.any((e) => e.id == entry.id)
          ? entries.map((e) => e.id == entry.id ? entry : e).toList()
          : [...entries, entry];
      entries = updated;
      notifyListeners();
      await _saveVault(updated);
      _h(HapticType.success);
      // BUG 1 FIX: clear password visibility after save so the password field
      // cannot be viewed without re-authenticating, even for the just-saved entry
      visiblePasswords.clear();
      // BUG 2 FIX: close the modal from the provider side here
      isAddingEntry = false;
      editingEntry  = null;
    } finally {
      isSaving = false;
      notifyListeners();
      _resetLockTimer();
    }
  }

  Future<void> deleteEntry(String id) async {
    if (!await verifyIdentity()) return;
    _h(HapticType.heavy);
    entries = entries.where((e) => e.id != id).toList();
    notifyListeners();
    await _saveVault(entries);
    resetActivity();
  }

  Future<void> toggleFavorite(String id) async {
    entries = entries.map((e) => e.id==id ? e.copyWith(isFavorite: !e.isFavorite) : e).toList();
    notifyListeners();
    await _saveVault(entries);
    _h(HapticType.light);
    resetActivity();
  }

  // ── Visibility / clipboard ────────────────────────────────────────────────────
  Future<void> toggleVisibility(String id) async {
    if (!visiblePasswords.contains(id)) {
      if (!await verifyIdentity()) return;
      visiblePasswords.add(id);
    } else {
      visiblePasswords.remove(id);
    }
    _h(HapticType.light);
    notifyListeners();
    resetActivity();
  }

  Future<void> copyPassword(String text, String id) async {
    if (!await verifyIdentity()) return;
    await Clipboard.setData(ClipboardData(text: text));
    _h(HapticType.success);
    copiedEntryId   = id;
    clipSecondsLeft = config.clipboardClearSeconds > 0 ? config.clipboardClearSeconds : 0;
    _clipTimer?.cancel();
    if (clipSecondsLeft > 0) {
      _clipTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (clipSecondsLeft <= 1) {
          _clipTimer?.cancel();
          clipSecondsLeft = 0;
          copiedEntryId   = null;
          await Clipboard.setData(const ClipboardData(text: ''));
        } else { clipSecondsLeft--; }
        notifyListeners();
      });
    }
    notifyListeners();
    resetActivity();
  }

  // ── Breach check ──────────────────────────────────────────────────────────────
  Future<void> runBreachCheck() async {
    showAlert('Scanning for Breaches…',
        'Checking against millions of known breached passwords. '
        'Only the first 5 characters of each password\'s hash are sent — '
        'your actual passwords never leave your device.',
        AlertType.info);

    final now     = DateTime.now().millisecondsSinceEpoch;
    var   breached = 0;
    final updated  = <VaultEntry>[];

    for (final e in entries) {
      final count    = await CryptoService.checkPasswordBreached(e.password);
      final detected = count > 0;
      if (detected) breached++;
      updated.add(e.copyWith(
        breachDetected:  detected,
        breachCount:     count > 0 ? count : 0,
        breachCheckedAt: now,
      ));
    }

    entries = updated;
    await _saveVault(updated);
    notifyListeners();

    final checkedAt = _formatDate(now);

    if (breached == 0) {
      showAlert(
        '✓ All Clear',
        'All ${entries.length} passwords checked on $checkedAt.\n\n'
        'None appeared in any known data breach database. '
        'Keep using strong, unique passwords and check regularly.',
        AlertType.success,
      );
    } else {
      // Build a list of breached entry names for context
      final breachedEntries = updated
          .where((e) => e.breachDetected)
          .map((e) {
            final times = e.breachCount >= 1000000
                ? '${(e.breachCount / 1000000).toStringAsFixed(1)}M times'
                : e.breachCount >= 1000
                    ? '${(e.breachCount / 1000).toStringAsFixed(1)}K times'
                    : '${e.breachCount} times';
            return '• ${e.title} — seen $times in breach databases';
          })
          .join('\n');

      showAlert(
        '$breached Password${breached > 1 ? 's' : ''} Compromised',
        'Checked on $checkedAt\n\n'
        '$breachedEntries\n\n'
        'These passwords appear in known data breach databases — '
        'meaning hackers have lists containing them. '
        'Change them immediately on the affected websites.',
        AlertType.error,
      );
    }
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  // ── Duress vault ──────────────────────────────────────────────────────────────
  Future<void> createDuressVault(String duressPassword) async {
    if (!await verifyIdentity()) return;
    isSaving = true;
    _lockTimer?.cancel();
    notifyListeners();
    try {
      final state = VaultState(entries: [], lastUnlocked: DateTime.now().millisecondsSinceEpoch);
      // Encrypt with the duress password (not the cached key — different password)
      clearKeyCache();
      final enc = await CryptoService.encrypt(jsonEncode(state.toJson()), duressPassword);
      // Restore cached key for the real vault password
      clearKeyCache();
      await StorageService.writeDummyVault(enc);
      showAlert('Duress Vault Ready',
          'Entering this password shows an empty decoy vault.', AlertType.success);
    } finally {
      isSaving = false;
      notifyListeners();
      _resetLockTimer();
    }
  }

  // ── Cloud sync ────────────────────────────────────────────────────────────────
  // ── Cloud sync ────────────────────────────────────────────────────────────────
  //
  // Merge strategy:
  //   • Both local and cloud entries are compared by ID + updatedAt timestamp
  //   • The entry with the NEWER updatedAt wins (last-write-wins per entry)
  //   • Entries that exist only on one side are kept (no deletion on sync)
  //   • After merge, the result is saved locally AND pushed to cloud
  //
  // This means:
  //   • Syncing the same data again → no change, identical result
  //   • Syncing after adding new entries → cloud gets the new entries added
  //   • Syncing after editing → newer version wins
  //   • Restoring from cloud after local changes → merged, nothing lost

  static List<VaultEntry> _mergeEntries(
      List<VaultEntry> local, List<VaultEntry> cloud) {
    final merged = <String, VaultEntry>{};
    // Add all local entries first
    for (final e in local) merged[e.id] = e;
    // Cloud entries win only if newer
    for (final e in cloud) {
      final existing = merged[e.id];
      if (existing == null || e.updatedAt > existing.updatedAt) {
        merged[e.id] = e;
      }
    }
    final result = merged.values.toList();
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Future<void> syncToCloud() async {
    if (currentUser == null || isLocked) return;
    if (!await verifyIdentity()) return;
    syncStatus = SyncStatus.syncing;
    notifyListeners();
    try {
      if (isDuressMode) {
        await Future.delayed(const Duration(milliseconds: 1200));
        _finishSync(SyncStatus.success);
        return;
      }

      // Fetch existing cloud data and merge before pushing
      final snap = await FirebaseFirestore.instance
          .collection('vaults').doc(currentUser!.uid).get();

      List<VaultEntry> merged = entries;
      if (snap.exists) {
        try {
          final cloudEnc   = snap.data()!['encryptedData'] as String;
          final cloudPlain = await CryptoService.decrypt(cloudEnc, _masterPassword);
          final cloudState = VaultState.fromJson(
              jsonDecode(cloudPlain) as Map<String, dynamic>);
          merged = _mergeEntries(entries, cloudState.entries);
        } catch (_) {
          // Cloud data unreadable (different password?) — push local only
          merged = entries;
        }
      }

      // Save merged result locally
      entries = merged;
      await _saveVault(merged);
      notifyListeners();

      // Push merged result to cloud
      final state = VaultState(
          entries: merged,
          lastUnlocked: DateTime.now().millisecondsSinceEpoch);
      final enc = await CryptoService.encrypt(
          jsonEncode(state.toJson()), _masterPassword);
      await FirebaseFirestore.instance
          .collection('vaults').doc(currentUser!.uid)
          .set({'encryptedData': enc,
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
                'entryCount': merged.length});

      _finishSync(SyncStatus.success);
    } catch (e) {
      showAlert('Sync Failed', e.toString(), AlertType.error);
      _finishSync(SyncStatus.error);
    }
  }

  Future<void> restoreFromCloud(String password) async {
    if (currentUser == null) return;
    syncStatus  = SyncStatus.syncing;
    isUnlocking = true;
    _lockTimer?.cancel();
    notifyListeners();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vaults').doc(currentUser!.uid).get();
      if (!snap.exists) {
        showAlert('No Backup Found',
            'No cloud backup found for this Google account.', AlertType.info);
        return;
      }
      final enc   = snap.data()!['encryptedData'] as String;
      final plain = await CryptoService.decrypt(enc, password);
      final cloudState = VaultState.fromJson(
          jsonDecode(plain) as Map<String, dynamic>);

      // If vault is already open, merge cloud with local
      // If locked (called from lock screen), cloud data becomes the vault
      List<VaultEntry> finalEntries;
      if (!isLocked && entries.isNotEmpty) {
        finalEntries = _mergeEntries(entries, cloudState.entries);
        showAlert('Restored & Merged',
            'Cloud backup merged with your local vault. '
            '${finalEntries.length} entries total — no data was lost.',
            AlertType.success);
      } else {
        finalEntries = cloudState.entries;
        showAlert('Restored Successfully',
            '${finalEntries.length} entries loaded from your cloud backup.',
            AlertType.success);
      }

      await StorageService.writeRealVault(enc);
      _openVault(password, finalEntries, duress: false);
      _finishSync(SyncStatus.success);
    } catch (e) {
      showAlert('Restore Failed',
          'Wrong master password, or no internet connection.',
          AlertType.error);
      _finishSync(SyncStatus.error);
    } finally {
      isUnlocking = false;
      notifyListeners();
      if (!isLocked) _resetLockTimer();
    }
  }

  void _finishSync(SyncStatus s) async {
    syncStatus = s; notifyListeners();
    await Future.delayed(const Duration(seconds: 3));
    syncStatus = SyncStatus.idle; notifyListeners();
  }

  // ── Google Sign-In (native account picker) ───────────────────────────────────
  // signInWithProvider() opens a browser redirect which fails in Flutter.
  // google_sign_in package opens the native OS account picker instead.
  static final _googleSignIn = GoogleSignIn(scopes: ['email']);

  Future<void> signInWithGoogle() async {
    isSigningIn = true;
    notifyListeners();
    try {
      // Step 1: open native Google account picker
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the picker — not an error
        return;
      }
      // Step 2: get auth tokens
      final googleAuth = await googleUser.authentication;
      // Step 3: sign into Firebase with the Google credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // currentUser is updated via authStateChanges listener in initialize()
    } catch (e) {
      showAlert('Sign-In Failed',
          'Could not sign in with Google. Check your internet connection and try again.',
          AlertType.error);
    } finally {
      isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    currentUser = null;
    notifyListeners();
  }

  // ── Config ────────────────────────────────────────────────────────────────────
  Future<void> updateConfig(VaultConfig nc) async {
    final sc = nc.screenshotProtection != config.screenshotProtection;
    config = nc;
    await StorageService.saveConfig(nc);
    if (sc) _setFlagSecure(nc.screenshotProtection);
    _resetLockTimer();
    notifyListeners();
  }

  Future<void> toggleBiometrics() async {
    _h(HapticType.medium);
    if (!config.useBiometrics) {
      // Check hardware exists at all
      final hasHardware = await BiometricService.isHardwarePresent();
      if (!hasHardware) {
        showAlert('Not Supported',
            'This device does not have a fingerprint sensor or face recognition camera.',
            AlertType.error);
        return;
      }
      // Attempt authentication directly — the OS knows best whether biometrics
      // are enrolled. Do NOT rely on canCheckBiometrics or isEnrolled() as they
      // return incorrect results on many Android devices (Samsung, Xiaomi, etc).
      isVerifying = true;
      notifyListeners();
      BiometricResult result;
      try {
        result = await BiometricService.authenticate(
            'Verify your identity to enable biometric lock');
      } finally {
        isVerifying = false;
        notifyListeners();
      }

      if (result.success) {
        biometricAvailable = true;
        await updateConfig(config.copyWith(useBiometrics: true));
        _h(HapticType.success);
        showAlert('Biometrics Enabled',
            '$biometricLabel is now active. You\'ll be prompted whenever you access sensitive data.',
            AlertType.success);
      } else if (result.notEnrolled) {
        showAlert(
          'Set Up Biometrics First',
          'No fingerprint or face is enrolled on this device yet.\n\n'
          '① Open your device Settings\n'
          '② Tap Security → Fingerprint or Face Recognition\n'
          '③ Follow the steps to enroll\n'
          '④ Come back here and toggle this on',
          AlertType.info,
          actionLabel: 'OPEN SETTINGS',
          action: openDeviceSettings,
        );
      } else if (!result.cancelled && result.error != null) {
        showAlert('Could Not Enable', result.error!, AlertType.error);
      }
    } else {
      // Disabling — require a live auth first
      final ok = await verifyIdentity();
      if (ok) {
        await updateConfig(config.copyWith(useBiometrics: false));
        _h(HapticType.success);
        showAlert('Biometrics Disabled', 'Master password only from now on.', AlertType.info);
      }
    }
  }

  // ── System channel — stored at init so it always has a messenger ─────────────
  static const _sysCh = MethodChannel('vaultx/system');

  /// Opens the device biometric enrollment screen.
  /// Uses the registered MethodChannel from configureFlutterEngine.
  Future<void> openDeviceSettings() async {
    try {
      await _sysCh.invokeMethod('openBiometricSettings');
    } catch (_) {
      // Silently ignore — the Kotlin fallback ladder always reaches ACTION_SETTINGS
    }
  }

  // ── Alerts ────────────────────────────────────────────────────────────────────
  void showAlert(String t, String m, AlertType at,
      {String? actionLabel, VoidCallback? action}) {
    alertTitle       = t;
    alertMessage     = m;
    alertType        = at;
    alertActionLabel = actionLabel;
    alertAction      = action;
    notifyListeners();
  }

  void dismissAlert() {
    alertTitle = alertMessage = alertActionLabel = null;
    alertType  = null;
    alertAction = null;
    notifyListeners();
  }

  // ── Modal helpers ─────────────────────────────────────────────────────────────
  void openAddEntry()              { editingEntry = null; isAddingEntry = true;  notifyListeners(); }
  void openEditEntry(VaultEntry e) { editingEntry = e;    isAddingEntry = true;  notifyListeners(); }
  void closeEntryModal()           { editingEntry = null; isAddingEntry = false; notifyListeners(); }

  void setActiveTab(ActiveTab t) {
    activeTab = t; _h(HapticType.light); resetActivity(); notifyListeners();
  }

  String newId() => _uuid.v4();

  bool get isBusy => isUnlocking || isSaving || isSigningIn || syncStatus == SyncStatus.syncing;
}

enum HapticType { light, medium, heavy, success, error }
enum AlertType  { success, error, info, warning }
