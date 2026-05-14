import 'dart:convert';
import 'dart:io';

import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class AppLockService {
  Future<bool> isSessionLocked();

  Future<bool> unlock();

  Future<void> lock();

  Future<bool> isBiometricLockEnabled();

  Future<void> setBiometricLockEnabled(bool enabled);
}

class LocalAppLockService implements AppLockService {
  LocalAppLockService({
    LocalAuthentication? localAuthentication,
  }) : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  static const String _biometricEnabledKey = 'app_lock.biometric_enabled';
  static const String _sessionLockedKey = 'app_lock.session_locked';
  Map<String, String>? _cache;

  @override
  Future<bool> isBiometricLockEnabled() async {
    return (await _readValue(_biometricEnabledKey)) == 'true';
  }

  @override
  Future<bool> isSessionLocked() async {
    if (!await isBiometricLockEnabled()) {
      return false;
    }
    return (await _readValue(_sessionLockedKey)) == 'true';
  }

  @override
  Future<void> lock() {
    return _writeValue(_sessionLockedKey, 'true');
  }

  @override
  Future<void> setBiometricLockEnabled(bool enabled) async {
    await _writeValue(_biometricEnabledKey, enabled ? 'true' : 'false');
    if (!enabled) {
      await _writeValue(_sessionLockedKey, 'false');
    }
  }

  @override
  Future<bool> unlock() async {
    if (!await isBiometricLockEnabled()) {
      await _writeValue(_sessionLockedKey, 'false');
      return true;
    }

    final bool canCheck = await _localAuthentication.canCheckBiometrics ||
        await _localAuthentication.isDeviceSupported();
    if (!canCheck) {
      await _writeValue(_sessionLockedKey, 'false');
      return true;
    }

    final bool authenticated = await _localAuthentication.authenticate(
      localizedReason: '請驗證裝置以解鎖 QuillLockDiary',
      biometricOnly: false,
      persistAcrossBackgrounding: true,
    );
    await _writeValue(_sessionLockedKey, authenticated ? 'false' : 'true');
    return authenticated;
  }

  Future<String?> _readValue(String key) async {
    final Map<String, String> store = await _loadStore();
    return store[key];
  }

  Future<void> _writeValue(String key, String value) async {
    final Map<String, String> store = await _loadStore();
    store[key] = value;
    await _persistStore(store);
  }

  Future<Map<String, String>> _loadStore() async {
    if (_cache != null) {
      return _cache!;
    }

    final File file = await _storageFile();
    if (!file.existsSync()) {
      _cache = <String, String>{};
      return _cache!;
    }

    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) {
      _cache = decoded.map(
        (String key, dynamic value) => MapEntry(key, value.toString()),
      );
    } else {
      _cache = <String, String>{};
    }
    return _cache!;
  }

  Future<void> _persistStore(Map<String, String> store) async {
    final File file = await _storageFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(store),
      flush: true,
    );
    _cache = Map<String, String>.from(store);
  }

  Future<File> _storageFile() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    return File(p.join(supportDir.path, 'quill_lock_diary', 'app_lock_store.json'));
  }
}

class UnsupportedAppLockService implements AppLockService {
  const UnsupportedAppLockService();

  @override
  Future<bool> isBiometricLockEnabled() async => false;

  @override
  Future<bool> isSessionLocked() async => false;

  @override
  Future<void> lock() async {}

  @override
  Future<void> setBiometricLockEnabled(bool enabled) async {}

  @override
  Future<bool> unlock() async => false;
}
