import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../db/database.dart';

/// Role of a vault — which one is the "real" data vs the decoy. Only used
/// internally to decide whether to show "Set/Change decoy" in Settings.
enum VaultRole { main, decoy }

class UnlockResult {
  final String vaultName;
  final VaultRole role;
  const UnlockResult({required this.vaultName, required this.role});
}

/// Wraps storage + hashing for the two-passcode (main + decoy) vault system.
///
/// Hashes use PBKDF2-HMAC-SHA256 with a random 16-byte salt and 100k iterations.
/// That's adequate for short numeric PINs against an attacker who has copied
/// the secure storage out of an unrooted device.
class PasscodeService {
  PasscodeService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kVaultAHash = 'vault_a_hash';
  static const _kVaultASalt = 'vault_a_salt';
  static const _kVaultARole = 'vault_a_role'; // "main" | "decoy"
  static const _kVaultBHash = 'vault_b_hash';
  static const _kVaultBSalt = 'vault_b_salt';
  static const _kVaultBRole = 'vault_b_role';

  static const int _iterations = 100000;
  static const int _saltBytes = 16;
  static const int _hashBytes = 32; // SHA-256 output

  // ── State checks ──────────────────────────────────────────────────────────

  /// True when no passcode has been set up yet — first-launch state.
  Future<bool> isFirstRun() async {
    final h = await _storage.read(key: _kVaultAHash);
    return h == null || h.isEmpty;
  }

  /// True when a decoy passcode exists (only meaningful from the main vault).
  Future<bool> hasDecoyConfigured() async {
    final h = await _storage.read(key: _kVaultBHash);
    return h != null && h.isNotEmpty;
  }

  // ── Setup ─────────────────────────────────────────────────────────────────

  /// First-launch setup: stores [passcode] as the MAIN vault (vault A).
  Future<void> setupMain(String passcode) async {
    _validatePasscode(passcode);
    final salt = _randomSalt();
    final hash = _pbkdf2(passcode, salt);
    await _writeVaultA(hash: hash, salt: salt, role: VaultRole.main);
  }

  /// Adds a decoy passcode. Must differ from any existing passcode.
  Future<void> setupDecoy(String passcode) async {
    _validatePasscode(passcode);
    // Reject duplicate vs current vault A passcode.
    if (await _verifyAgainstVaultA(passcode)) {
      throw PasscodeException('Choose a different passcode.');
    }
    // Vault A has role=main (we always set it up that way). Decoy is vault B.
    final salt = _randomSalt();
    final hash = _pbkdf2(passcode, salt);
    await _writeVaultB(hash: hash, salt: salt, role: VaultRole.decoy);
  }

  // ── Unlock ────────────────────────────────────────────────────────────────

  /// Hash [passcode] against each configured vault. Returns the unlocked one,
  /// or null if no match.
  Future<UnlockResult?> tryUnlock(String passcode) async {
    if (passcode.trim().isEmpty) return null;

    // Try vault A first.
    if (await _verifyAgainstVaultA(passcode)) {
      final role = await _readRole(_kVaultARole) ?? VaultRole.main;
      return UnlockResult(vaultName: kVaultA, role: role);
    }
    // Then vault B.
    if (await _verifyAgainstVaultB(passcode)) {
      final role = await _readRole(_kVaultBRole) ?? VaultRole.decoy;
      return UnlockResult(vaultName: kVaultB, role: role);
    }
    return null;
  }

  // ── Change passcode ──────────────────────────────────────────────────────

  /// Change the passcode for [vaultName]. Caller is expected to have
  /// reauthenticated the user (i.e. they're inside this vault).
  Future<void> changePasscode({
    required String vaultName,
    required String newPasscode,
  }) async {
    _validatePasscode(newPasscode);
    // Reject if the new passcode collides with the OTHER vault's passcode.
    final otherVault = vaultName == kVaultA ? kVaultB : kVaultA;
    if (await _verifyAgainstVault(otherVault, newPasscode)) {
      throw PasscodeException('Choose a different passcode.');
    }
    final salt = _randomSalt();
    final hash = _pbkdf2(newPasscode, salt);
    final role = await _readRole(
            vaultName == kVaultA ? _kVaultARole : _kVaultBRole) ??
        VaultRole.main;
    if (vaultName == kVaultA) {
      await _writeVaultA(hash: hash, salt: salt, role: role);
    } else {
      await _writeVaultB(hash: hash, salt: salt, role: role);
    }
  }

  /// Removes vault B credentials (used by decoy wipe flow if ever needed).
  /// Note: this does NOT delete the vault B database file.
  Future<void> clearVaultB() async {
    await _storage.delete(key: _kVaultBHash);
    await _storage.delete(key: _kVaultBSalt);
    await _storage.delete(key: _kVaultBRole);
  }

  // ── Internals ────────────────────────────────────────────────────────────

  void _validatePasscode(String p) {
    final t = p.trim();
    if (t.length < 4) {
      throw PasscodeException('Passcode must be at least 4 digits.');
    }
    if (t.length > 16) {
      throw PasscodeException('Passcode is too long.');
    }
  }

  Future<bool> _verifyAgainstVaultA(String passcode) =>
      _verifyAgainstVault(kVaultA, passcode);

  Future<bool> _verifyAgainstVaultB(String passcode) =>
      _verifyAgainstVault(kVaultB, passcode);

  Future<bool> _verifyAgainstVault(String vault, String passcode) async {
    final hashKey = vault == kVaultA ? _kVaultAHash : _kVaultBHash;
    final saltKey = vault == kVaultA ? _kVaultASalt : _kVaultBSalt;
    final storedHash = await _storage.read(key: hashKey);
    final storedSalt = await _storage.read(key: saltKey);
    if (storedHash == null ||
        storedSalt == null ||
        storedHash.isEmpty ||
        storedSalt.isEmpty) {
      return false;
    }
    final candidate = _pbkdf2(passcode, base64Decode(storedSalt));
    return _constantTimeEq(candidate, base64Decode(storedHash));
  }

  Future<void> _writeVaultA({
    required Uint8List hash,
    required Uint8List salt,
    required VaultRole role,
  }) async {
    await _storage.write(key: _kVaultAHash, value: base64Encode(hash));
    await _storage.write(key: _kVaultASalt, value: base64Encode(salt));
    await _storage.write(key: _kVaultARole, value: _roleString(role));
  }

  Future<void> _writeVaultB({
    required Uint8List hash,
    required Uint8List salt,
    required VaultRole role,
  }) async {
    await _storage.write(key: _kVaultBHash, value: base64Encode(hash));
    await _storage.write(key: _kVaultBSalt, value: base64Encode(salt));
    await _storage.write(key: _kVaultBRole, value: _roleString(role));
  }

  Future<VaultRole?> _readRole(String key) async {
    final s = await _storage.read(key: key);
    return switch (s) {
      'main' => VaultRole.main,
      'decoy' => VaultRole.decoy,
      _ => null,
    };
  }

  static String _roleString(VaultRole r) =>
      r == VaultRole.main ? 'main' : 'decoy';

  static Uint8List _randomSalt() {
    final r = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(_saltBytes, (_) => r.nextInt(256)));
  }

  /// PBKDF2-HMAC-SHA256 — pure-Dart implementation using `package:crypto`'s Hmac.
  static Uint8List _pbkdf2(String passcode, Uint8List salt) {
    final passBytes = utf8.encode(passcode.trim());
    final mac = Hmac(sha256, passBytes);
    const hLen = _hashBytes;
    final blocksNeeded = (hLen / hLen).ceil(); // 1 block — we only need 32 bytes
    final out = BytesBuilder();
    for (var blockIndex = 1; blockIndex <= blocksNeeded; blockIndex++) {
      // U1 = PRF(P, S || INT(i))
      final block = Uint8List(salt.length + 4);
      block.setRange(0, salt.length, salt);
      block[salt.length]     = (blockIndex >> 24) & 0xff;
      block[salt.length + 1] = (blockIndex >> 16) & 0xff;
      block[salt.length + 2] = (blockIndex >>  8) & 0xff;
      block[salt.length + 3] = blockIndex         & 0xff;
      var u = Uint8List.fromList(mac.convert(block).bytes);
      final tBlock = Uint8List.fromList(u);
      for (var i = 1; i < _iterations; i++) {
        u = Uint8List.fromList(mac.convert(u).bytes);
        for (var j = 0; j < hLen; j++) {
          tBlock[j] ^= u[j];
        }
      }
      out.add(tBlock);
    }
    final full = out.takeBytes();
    return Uint8List.fromList(full.sublist(0, hLen));
  }

  /// Constant-time byte equality so timing attacks can't differentiate two
  /// candidate hashes.
  static bool _constantTimeEq(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class PasscodeException implements Exception {
  final String message;
  PasscodeException(this.message);
  @override
  String toString() => message;
}
