// services/biometric_service.dart — v4
//
// Root cause of "not enrolled" showing when biometrics ARE enrolled:
//
// canCheckBiometrics returns false on many Android devices even when
// biometrics are enrolled — it checks if the app is ALLOWED to use
// biometrics for authentication, not whether biometrics exist.
// Some OEM ROMs (Samsung, Xiaomi, Oppo) restrict this flag.
//
// Fix: remove canCheckBiometrics from the enrollment check entirely.
// Instead rely solely on getAvailableBiometrics() which directly queries
// the biometric subsystem. Also: never gate toggleBiometrics on isEnrolled()
// — just attempt authentication and let the OS show the system prompt.
// If enrollment is truly missing, the OS will report it via PlatformException.

import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  // Always create a fresh instance — static singleton loses Activity context
  static LocalAuthentication _make() => LocalAuthentication();

  /// True if the device has biometric hardware AND at least one method enrolled.
  /// Does NOT check canCheckBiometrics — unreliable on many OEM ROMs.
  static Future<bool> isAvailable() async {
    try {
      final auth = _make();
      // isDeviceSupported() = has secure lock screen (PIN/pattern/password)
      if (!await auth.isDeviceSupported()) return false;
      // getAvailableBiometrics() returns non-empty only when biometrics are
      // enrolled AND the hardware is present and working
      final types = await auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      // If anything throws, fall back to true so we still try — the
      // authenticate() call itself will tell us the real story
      return true;
    }
  }

  /// Same as isAvailable — kept for call sites that use isEnrolled()
  static Future<bool> isEnrolled() => isAvailable();

  /// True if the device has biometric hardware at all (even if not enrolled)
  static Future<bool> isHardwarePresent() async {
    try {
      return await _make().isDeviceSupported();
    } catch (_) { return false; }
  }

  static Future<String> getBiometricLabel() async {
    try {
      final types = await _make().getAvailableBiometrics();
      if (types.contains(BiometricType.face))        return 'Face ID';
      if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
      if (types.contains(BiometricType.iris))        return 'Iris Scanner';
      if (types.contains(BiometricType.strong))      return 'Biometrics';
      if (types.contains(BiometricType.weak))        return 'Biometrics';
      // No types found but hardware present — generic label
      return 'Fingerprint';
    } catch (_) { return 'Fingerprint'; }
  }

  static Future<BiometricResult> authenticate(String reason) async {
    try {
      final ok = await _make().authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,  // allow device PIN as fallback
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
      return ok ? BiometricResult.success() : BiometricResult.cancelled();
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NotEnrolled':
          return BiometricResult.notEnrolled();
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return BiometricResult.failure(
              'Too many failed attempts. Please use your device PIN.');
        case 'NotAvailable':
        case 'OtherOperatingSystem':
          return BiometricResult.failure(
              'Biometrics not available right now. Try using your PIN.');
        case 'PasscodeNotSet':
          return BiometricResult.failure(
              'Please set a device PIN or password first, then enroll a fingerprint.');
        default:
          // Log the code for debugging — shown as part of message
          final msg = e.message ?? 'Authentication failed';
          final code = e.code;
          return BiometricResult.failure('$msg (code: $code)');
      }
    } catch (e) {
      return BiometricResult.failure('Unexpected error: ${e.toString()}');
    }
  }
}

class BiometricResult {
  final bool    success;
  final bool    cancelled;
  final bool    notEnrolled;
  final String? error;

  BiometricResult._({
    required this.success,
    this.cancelled   = false,
    this.notEnrolled = false,
    this.error,
  });

  factory BiometricResult.success()            => BiometricResult._(success: true);
  factory BiometricResult.cancelled()          => BiometricResult._(success: false, cancelled: true);
  factory BiometricResult.notEnrolled()        => BiometricResult._(success: false, notEnrolled: true);
  factory BiometricResult.failure(String msg)  => BiometricResult._(success: false, error: msg);
}
