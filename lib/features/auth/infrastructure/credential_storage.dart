import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStorage {
  static const _keyEmail = 'cred_email';
  static const _keyRefreshToken = 'cred_refresh_token';
  static const _keyRemember = 'cred_remember_me';
  static const _keyPassword = 'cred_password';
  static const _keyPinHash = 'cred_pin_hash';
  static const _keyPinSalt = 'cred_pin_salt';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Random _random = Random.secure();

  Future<void> saveRememberMe(bool remember) async {
    await _storage.write(key: _keyRemember, value: remember ? '1' : '0');
  }

  Future<bool?> readRememberMe() async {
    final v = await _storage.read(key: _keyRemember);
    if (v == null) return null;
    return v == '1';
  }

  Future<void> saveEmail(String email) async {
    await _storage.write(key: _keyEmail, value: email);
  }

  Future<String?> readEmail() async {
    return _storage.read(key: _keyEmail);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<String?> readRefreshToken() async {
    return _storage.read(key: _keyRefreshToken);
  }

  Future<void> savePassword(String password) async {
    await _storage.write(key: _keyPassword, value: password);
  }

  Future<String?> readPassword() async {
    return _storage.read(key: _keyPassword);
  }

  Future<void> clearPassword() async {
    await _storage.delete(key: _keyPassword);
  }

  Future<void> savePin(String pin) async {
    final saltBytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final salt = base64Encode(saltBytes);
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _keyPinSalt, value: salt);
    await _storage.write(key: _keyPinHash, value: hash);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _keyPinSalt);
    final storedHash = await _storage.read(key: _keyPinHash);
    if (salt == null || storedHash == null) return false;
    final hash = _hashPin(pin, salt);
    return hash == storedHash;
  }

  Future<bool> hasPin() async {
    final storedHash = await _storage.read(key: _keyPinHash);
    return storedHash != null && storedHash.isNotEmpty;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _keyPinHash);
    await _storage.delete(key: _keyPinSalt);
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyRemember);
    await _storage.delete(key: _keyPassword);
    await clearPin();
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
