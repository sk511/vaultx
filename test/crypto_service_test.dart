import 'package:flutter_test/flutter_test.dart';
import 'package:fortress_flutter/services/crypto_service.dart';

void main() {
  group('CryptoService — encrypt / decrypt', () {
    const password  = 'superSecretMasterPassword123!';
    const plaintext = '{"entries":[],"version":2}';

    test('encrypt produces non-empty base64 string', () {
      final enc = CryptoService.encrypt(plaintext, password);
      expect(enc, isNotEmpty);
      expect(enc, isNot(equals(plaintext)));
    });

    test('decrypt recovers original plaintext', () {
      final enc  = CryptoService.encrypt(plaintext, password);
      final dec  = CryptoService.decrypt(enc, password);
      expect(dec, equals(plaintext));
    });

    test('two encryptions of same data produce different ciphertext (random IV)', () {
      final enc1 = CryptoService.encrypt(plaintext, password);
      final enc2 = CryptoService.encrypt(plaintext, password);
      expect(enc1, isNot(equals(enc2)));
    });

    test('wrong password throws exception', () {
      final enc = CryptoService.encrypt(plaintext, password);
      expect(() => CryptoService.decrypt(enc, 'wrongPassword'), throwsException);
    });

    test('tampered ciphertext throws exception', () {
      var enc    = CryptoService.encrypt(plaintext, password);
      final chars = enc.split('');
      chars[30]  = chars[30] == 'A' ? 'B' : 'A';
      final bad  = chars.join();
      expect(() => CryptoService.decrypt(bad, password), throwsException);
    });
  });

  group('CryptoService — password generator', () {
    test('generatePassword returns correct length', () {
      for (final len in [12, 16, 20, 24, 32]) {
        expect(CryptoService.generatePassword(length: len).length, equals(len));
      }
    });

    test('generatePassword with all charsets contains expected characters', () {
      // Run many times to statistically guarantee character class coverage
      final passwords = List.generate(20, (_) =>
          CryptoService.generatePassword(length: 32));
      final combined = passwords.join();
      expect(combined, matches(RegExp(r'[a-z]')));
      expect(combined, matches(RegExp(r'[A-Z]')));
      expect(combined, matches(RegExp(r'[0-9]')));
      expect(combined, matches(RegExp(r'[!@#\$%^&*]')));
    });

    test('generatePassphrase returns correct word count', () {
      for (final count in [3, 4, 5, 6]) {
        final phrase = CryptoService.generatePassphrase(wordCount: count);
        expect(phrase.split('-').length, equals(count));
      }
    });
  });

  group('CryptoService — password strength', () {
    test('empty password returns score 0', () {
      final s = CryptoService.analyseStrength('');
      expect(s.score, equals(0));
      expect(s.label, equals('None'));
    });

    test('short simple password scores low', () {
      final s = CryptoService.analyseStrength('abc');
      expect(s.score, lessThan(3));
    });

    test('long complex password scores high', () {
      final s = CryptoService.analyseStrength('Tr0ub4dor&3-Correct-Battery-Staple!');
      expect(s.score, equals(5));
      expect(s.entropy, greaterThan(60));
    });

    test('suggestions provided for weak password', () {
      final s = CryptoService.analyseStrength('hello');
      expect(s.suggestions, isNotEmpty);
    });

    test('crack time is not instant for strong password', () {
      final s = CryptoService.analyseStrength('Xk9#mP2!vQ7@nL4\$');
      expect(s.crackTime, isNot(equals('instant')));
    });
  });

  group('CryptoService — TOTP (RFC 6238)', () {
    // Test vector from RFC 6238 with well-known secret
    const secret = 'JBSWY3DPEHPK3PXP'; // = "Hello!" in base32

    test('generateTOTP returns 6-digit code', () {
      final result = CryptoService.generateTOTP(secret);
      expect(result.code.length, equals(6));
      expect(int.tryParse(result.code), isNotNull);
    });

    test('secondsRemaining is between 1 and 30', () {
      final result = CryptoService.generateTOTP(secret);
      expect(result.secondsRemaining, greaterThan(0));
      expect(result.secondsRemaining, lessThanOrEqualTo(30));
    });

    test('consecutive calls within same 30s window return same code', () {
      final r1 = CryptoService.generateTOTP(secret);
      final r2 = CryptoService.generateTOTP(secret);
      // Both are called within the same test run (same 30s window)
      expect(r1.code, equals(r2.code));
    });
  });
}
