// services/crypto_service.dart — v5
//
// Bug fixes:
//
// BUG 3 FIX — zero-salt sentinel corruption:
//   Previous version used salt=0x00...00 as a sentinel to signal "key is pre-derived".
//   After lockVault() clears the cache, decrypt() tried to use PBKDF2 with the actual
//   stored salt bytes — which were all zeros. PBKDF2(password, salt=zeros) produces a
//   completely different key than PBKDF2(password, real_salt), so decryption fails.
//   The vault then fell through to try the duress vault, which might succeed.
//
//   FIX: ALWAYS store the real random salt. The key cache is purely a runtime
//   performance optimisation — it never touches the on-disk wire format.
//   encrypt() always writes: salt[16] | iv[12] | ciphertext+tag
//   decrypt() always reads:  salt[16] | iv[12] | ciphertext+tag
//   If cache hit → skip PBKDF2 (fast). If miss → run PBKDF2 with stored salt (correct).

import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:convert/convert.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const int _pbkdf2Iterations = 10000;
const int _keyBytes         = 32;
const int _saltLen          = 16;
const int _ivLen            = 12;
const int _tagLen           = 16;

// ─── Runtime key cache — session only, cleared on lock ───────────────────────
// Stores the PBKDF2-derived key so re-encrypts within a session skip PBKDF2.
// Does NOT affect on-disk format — salt is always stored with the ciphertext.
Uint8List? _cachedKey;
String?    _cachedSalt;    // hex of the salt used to derive _cachedKey
String?    _cachedPassword;

void clearKeyCache() {
  _cachedKey      = null;
  _cachedSalt     = null;
  _cachedPassword = null;
}

// ─── Pure helpers (called inside Isolate only) ────────────────────────────────

Uint8List _rndBytes(int n) {
  final r = Random.secure();
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

Uint8List _deriveKey(String password, Uint8List salt) {
  final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyBytes));
  return kdf.process(Uint8List.fromList(utf8.encode(password)));
}

Uint8List _aesGcmEncrypt(Uint8List key, Uint8List iv, Uint8List plaintext) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(key), _tagLen * 8, iv, Uint8List(0)));
  return cipher.process(plaintext);
}

Uint8List _aesGcmDecrypt(Uint8List key, Uint8List iv, Uint8List ciphertext) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(false, AEADParameters(KeyParameter(key), _tagLen * 8, iv, Uint8List(0)));
  try {
    return cipher.process(ciphertext);
  } catch (_) {
    throw Exception('Invalid master password or corrupted data');
  }
}

// ─── Isolate message types ────────────────────────────────────────────────────

class _EncRequest {
  final String data, password;
  final Uint8List? preKey;    // skip PBKDF2
  final Uint8List? preSalt;   // reuse this salt (must match preKey derivation)
  const _EncRequest(this.data, this.password, {this.preKey, this.preSalt});
}

class _EncResult {
  final String? ciphertext;
  final Uint8List? derivedKey;
  final String? saltHex;
  final String? err;
  const _EncResult({this.ciphertext, this.derivedKey, this.saltHex, this.err});
}

class _DecRequest {
  final String b64, password;
  final Uint8List? preKey;     // if provided, skip PBKDF2
  const _DecRequest(this.b64, this.password, {this.preKey});
}

class _DecResult {
  final String? plaintext;
  final Uint8List? derivedKey;
  final String? saltHex;
  final String? err;
  const _DecResult({this.plaintext, this.derivedKey, this.saltHex, this.err});
}

// ─── Isolate entry points ─────────────────────────────────────────────────────

_EncResult _isolateEncrypt(_EncRequest r) {
  try {
    // Use provided salt (fast-path re-encrypt) or generate a fresh one (first encrypt)
    final salt = r.preSalt ?? _rndBytes(_saltLen);
    final iv   = _rndBytes(_ivLen);   // always fresh IV — required by GCM
    final key  = r.preKey ?? _deriveKey(r.password, salt);
    final ct   = _aesGcmEncrypt(key, iv, Uint8List.fromList(utf8.encode(r.data)));

    final combined = Uint8List(_saltLen + _ivLen + ct.length)
      ..setAll(0, salt)
      ..setAll(_saltLen, iv)
      ..setAll(_saltLen + _ivLen, ct);

    return _EncResult(
      ciphertext: base64.encode(combined),
      derivedKey: key,
      saltHex:    hex.encode(salt),
    );
  } catch (e) {
    return _EncResult(err: e.toString());
  }
}

_DecResult _isolateDecrypt(_DecRequest r) {
  try {
    final combined   = base64.decode(r.b64);
    final saltBytes  = combined.sublist(0, _saltLen);
    final iv         = combined.sublist(_saltLen, _saltLen + _ivLen);
    final ciphertext = combined.sublist(_saltLen + _ivLen);

    // Use pre-derived key if provided (fast path), else run PBKDF2
    final key = r.preKey ?? _deriveKey(r.password, Uint8List.fromList(saltBytes));

    final plain = _aesGcmDecrypt(
      Uint8List.fromList(key), Uint8List.fromList(iv), Uint8List.fromList(ciphertext));

    return _DecResult(
      plaintext:  utf8.decode(plain),
      derivedKey: key,
      saltHex:    hex.encode(saltBytes),
    );
  } catch (e) {
    return _DecResult(err: e.toString());
  }
}

// ─── Public CryptoService ─────────────────────────────────────────────────────

class CryptoService {
  /// Decrypt in background isolate. Caches derived key for fast re-encrypts.
  /// After lock/clearKeyCache(), always re-derives with PBKDF2 using stored salt.
  static Future<String> decrypt(String b64, String password) async {
    // Fast path: we have a cached key AND the stored salt matches what we derived with
    if (_cachedKey != null && _cachedPassword == password && _cachedSalt != null) {
      try {
        // Extract salt from stored data and verify it matches our cached derivation
        final combined = base64.decode(b64);
        final storedSaltHex = hex.encode(combined.sublist(0, _saltLen));
        if (storedSaltHex == _cachedSalt) {
          // Salt matches — safe to use cached key, skip PBKDF2
          final res = await Isolate.run(
              () => _isolateDecrypt(_DecRequest(b64, password, preKey: _cachedKey)));
          if (res.err == null) return res.plaintext!;
          // Unexpected failure — fall through to full decrypt
        }
      } catch (_) {}
    }

    // Slow path: full PBKDF2 + AES-GCM in isolate
    final res = await Isolate.run(() => _isolateDecrypt(_DecRequest(b64, password)));
    if (res.err != null) throw Exception(res.err);

    // Cache the key + the salt it was derived from
    _cachedKey      = res.derivedKey;
    _cachedPassword = password;
    _cachedSalt     = res.saltHex;
    return res.plaintext!;
  }

  /// Encrypt in background isolate. Uses cached key if available → skips PBKDF2.
  /// Always writes a real random salt — never zeros.
  static Future<String> encrypt(String data, String password) async {
    // Fast path: cached key exists — use it with its original salt so
    // decrypt() can always verify salt matches and use the same key.
    // A fresh random IV is still generated for every encrypt (GCM requirement).
    if (_cachedKey != null && _cachedPassword == password && _cachedSalt != null) {
      final key      = _cachedKey!;
      final saltBytes = Uint8List.fromList(hex.decode(_cachedSalt!));
      final res = await Isolate.run(
          () => _isolateEncrypt(_EncRequest(data, password, preKey: key, preSalt: saltBytes)));
      if (res.err != null) throw Exception(res.err);
      return res.ciphertext!;
    }

    // Slow path: full PBKDF2 — generates new random salt, derives fresh key
    final res = await Isolate.run(() => _isolateEncrypt(_EncRequest(data, password)));
    if (res.err != null) throw Exception(res.err);
    _cachedKey      = res.derivedKey;
    _cachedPassword = password;
    _cachedSalt     = res.saltHex;
    return res.ciphertext!;
  }

  // ── Password generator ────────────────────────────────────────────────────
  static const _lo = 'abcdefghijklmnopqrstuvwxyz';
  static const _up = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _di = '0123456789';
  static const _sy = r'!@#$%^&*()_+~`|}{[]:;?><,./-=';

  static String generatePassword({
    int length = 20, bool useLower = true, bool useUpper = true,
    bool useNumbers = true, bool useSymbols = true,
  }) {
    var cs = '';
    if (useLower)   cs += _lo;
    if (useUpper)   cs += _up;
    if (useNumbers) cs += _di;
    if (useSymbols) cs += _sy;
    if (cs.isEmpty) cs = _lo;
    final rng = Random.secure();
    return String.fromCharCodes(
        List.generate(length, (_) => cs.codeUnitAt(rng.nextInt(cs.length))));
  }

  static const _words = [
    'apple','arctic','anchor','beacon','blaze','bridge','candle','castle','coral',
    'dawn','dragon','dusk','eagle','ember','falcon','forest','frost','garden',
    'gloom','harbor','hollow','island','ivory','jasper','jungle','karma','kitten',
    'lantern','lunar','maple','mountain','nebula','nova','ocean','olive','pearl',
    'pepper','quest','quartz','rebel','river','silver','storm','thunder','tide',
    'ultra','umbrella','vault','violet','walnut','whisper','xenith','yarn','yellow',
    'zenith','zephyr','basin','citadel','delta','forge','granite','helix','iris',
    'kestrel','lapis','mesa','nexus','orbit','prism','quasar','ridge','solstice',
    'talon','umbra','vertex','willow','xylem','yonder',
  ];

  static String generatePassphrase({int wordCount = 4}) {
    final rng = Random.secure();
    return List.generate(wordCount, (_) => _words[rng.nextInt(_words.length)]).join('-');
  }

  // ── Strength ──────────────────────────────────────────────────────────────
  static PasswordStrength analyseStrength(String pw) {
    if (pw.isEmpty) return const PasswordStrength(
        score: 0, label: 'None', color: 0xFF3F3F46,
        entropy: 0, crackTime: 'instant', suggestions: []);
    var score = 0;
    final sugg = <String>[];
    if (pw.length >= 8)  score++;
    if (pw.length >= 14) score++;
    final hasU = RegExp(r'[A-Z]').hasMatch(pw);
    final hasD = RegExp(r'[0-9]').hasMatch(pw);
    final hasS = RegExp(r'[^A-Za-z0-9]').hasMatch(pw);
    if (hasU) score++; else sugg.add('Add uppercase letters');
    if (hasD) score++; else sugg.add('Add numbers');
    if (hasS) score++; else sugg.add('Add symbols (!@#\$…)');
    if (pw.length < 8) sugg.insert(0, 'Use at least 8 characters');
    var pool = 0;
    if (RegExp(r'[a-z]').hasMatch(pw)) pool += 26;
    if (hasU) pool += 26; if (hasD) pool += 10; if (hasS) pool += 32;
    final entropy = pool > 1 ? (pw.length * log(pool) / log(2)).floor() : 0;
    final secs = pow(2.0, entropy.toDouble()) / 1e10;
    String ct;
    if      (secs > 31536000000) ct = 'centuries';
    else if (secs > 31536000)    ct = '${(secs/31536000).floor()} years';
    else if (secs > 86400)       ct = '${(secs/86400).floor()} days';
    else if (secs > 3600)        ct = '${(secs/3600).floor()} hours';
    else if (secs > 60)          ct = '${(secs/60).floor()} minutes';
    else if (secs > 1)           ct = '${secs.floor()} seconds';
    else                         ct = 'instant';
    const lv = [
      (l:'Very Weak',c:0xFFEF4444),(l:'Weak',c:0xFFF97316),(l:'Fair',c:0xFFEAB308),
      (l:'Good',c:0xFF3B82F6),(l:'Strong',c:0xFF10B981),(l:'Very Strong',c:0xFF34D399),
    ];
    final cp = score.clamp(0, 5);
    return PasswordStrength(score:cp,label:lv[cp].l,color:lv[cp].c,
        entropy:entropy,crackTime:ct,suggestions:sugg);
  }

  // ── TOTP ──────────────────────────────────────────────────────────────────
  static Uint8List _b32(String s) {
    const a = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final clean = s.toUpperCase().replaceAll(RegExp(r'[= ]'),'');
    var bits = 0, val = 0; final out = <int>[];
    for (final ch in clean.split('')) {
      final i = a.indexOf(ch); if (i<0) continue;
      val = (val<<5)|i; bits+=5;
      if (bits>=8) { bits-=8; out.add((val>>bits)&0xff); }
    }
    return Uint8List.fromList(out);
  }

  static TotpResult generateTOTP(String secret, {int digits=6}) {
    final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ctr   = epoch ~/ 30;
    final rem   = 30 - (epoch % 30);
    final cb    = Uint8List(8);
    var c = ctr;
    for (var i=7;i>=0;i--) { cb[i]=c&0xff; c>>=8; }
    final sig  = crypto.Hmac(crypto.sha1, _b32(secret)).convert(cb).bytes;
    final off  = sig[sig.length-1] & 0x0f;
    final code = (((sig[off]&0x7f)<<24)|((sig[off+1]&0xff)<<16)|
                  ((sig[off+2]&0xff)<<8)|(sig[off+3]&0xff))
                 % pow(10,digits).toInt();
    return TotpResult(code: code.toString().padLeft(digits,'0'),
                      secondsRemaining: rem);
  }

  // ── Breach check ──────────────────────────────────────────────────────────
  static Future<int> checkPasswordBreached(String pw) async {
    try {
      final hx = hex.encode(crypto.sha1.convert(utf8.encode(pw)).bytes).toUpperCase();
      final resp = await http.get(
        Uri.parse('https://api.pwnedpasswords.com/range/${hx.substring(0,5)}'),
        headers: {'Add-Padding':'true'}).timeout(const Duration(seconds:8));
      if (resp.statusCode != 200) return 0;
      for (final ln in resp.body.split('\n')) {
        final p = ln.split(':');
        if (p.length<2) continue;
        if (p[0].trim().toUpperCase() == hx.substring(5))
          return int.tryParse(p[1].trim()) ?? 0;
      }
      return 0;
    } catch (_) { return -1; }
  }
}

// ─── Value types ──────────────────────────────────────────────────────────────
class PasswordStrength {
  final int score, entropy, color;
  final String label, crackTime;
  final List<String> suggestions;
  const PasswordStrength({required this.score, required this.label,
      required this.color, required this.entropy, required this.crackTime,
      required this.suggestions});
}

class TotpResult {
  final String code;
  final int secondsRemaining;
  const TotpResult({required this.code, required this.secondsRemaining});
}
