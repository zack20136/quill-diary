import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_unlock_mode.dart';
import 'keystore_unlock_policy.dart';

abstract class AppLockService {
  Future<AppUnlockMode> getUnlockMode();

  Future<void> setUnlockMode(AppUnlockMode mode);

  Future<KeystoreAuthKind> keystoreAuthKindForCurrentMode();

  Future<bool> canUseDeviceCredential();
}

class LocalAppLockService implements AppLockService {
  LocalAppLockService();

  static const String _unlockModeKey = 'app_lock.unlock_mode';

  static const MethodChannel _deviceKeyChannel =
      MethodChannel('quill_lock_diary/device_key_bridge');

  Map<String, String>? _cache;

  @override
  Future<AppUnlockMode> getUnlockMode() async {
    final String? raw = await _readValue(_unlockModeKey);
    return AppUnlockModeStorage.fromStorage(raw);
  }

  @override
  Future<void> setUnlockMode(AppUnlockMode mode) async {
    await _writeValue(_unlockModeKey, mode.storageValue);
  }

  @override
  Future<KeystoreAuthKind> keystoreAuthKindForCurrentMode() async {
    return keystoreAuthFor(await getUnlockMode());
  }

  @override
  Future<bool> canUseDeviceCredential() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final bool? ok = await _deviceKeyChannel.invokeMethod<bool>('canUseDeviceCredential');
      return ok ?? false;
    } on PlatformException {
      return false;
    }
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
  Future<AppUnlockMode> getUnlockMode() async => AppUnlockMode.none;

  @override
  Future<void> setUnlockMode(AppUnlockMode mode) async {}

  @override
  Future<KeystoreAuthKind> keystoreAuthKindForCurrentMode() async => KeystoreAuthKind.plain;

  @override
  Future<bool> canUseDeviceCredential() async => false;
}
