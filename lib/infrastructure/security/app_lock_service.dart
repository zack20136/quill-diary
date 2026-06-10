import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../config/app_identifiers.dart';
import 'app_unlock_mode.dart';
import 'keystore_unlock_policy.dart';
import 'unlock_mode_policy.dart';

/// Persists the user's preferred trusted-device unlock policy outside the vault.
abstract class AppLockService {
  Future<AppUnlockMode> getUnlockMode();

  Future<void> setUnlockMode(AppUnlockMode mode);

  Future<KeystoreAuthKind> keystoreAuthKindForCurrentMode();

  Future<bool> canUseDeviceCredential();

  Future<bool> canUseBiometric();

  Future<DeviceAuthCapabilities> getDeviceAuthCapabilities();
}

/// File-backed app-lock preferences plus native Android credential capability checks.
class LocalAppLockService implements AppLockService {
  LocalAppLockService();

  static const String _unlockModeKey = 'app_lock.unlock_mode';

  static const MethodChannel _deviceKeyChannel =
      MethodChannel(AppIdentifiers.deviceKeyChannel);

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
    return requireKeystoreAuthKindForMode(
      appLock: this,
      mode: await getUnlockMode(),
    );
  }

  @override
  Future<bool> canUseDeviceCredential() async {
    final DeviceAuthCapabilities capabilities = await getDeviceAuthCapabilities();
    return capabilities.deviceCredentialAvailable;
  }

  @override
  Future<bool> canUseBiometric() async {
    final DeviceAuthCapabilities capabilities = await getDeviceAuthCapabilities();
    return capabilities.biometricStrongAvailable;
  }

  @override
  Future<DeviceAuthCapabilities> getDeviceAuthCapabilities() async {
    if (!Platform.isAndroid) {
      return const DeviceAuthCapabilities(
        deviceCredentialAvailable: false,
        biometricStrongAvailable: false,
      );
    }
    try {
      final Map<Object?, Object?>? result =
          await _deviceKeyChannel.invokeMapMethod<Object?, Object?>(
        'getDeviceAuthCapabilities',
      );
      return DeviceAuthCapabilities(
        deviceCredentialAvailable: result?['deviceCredential'] == true,
        biometricStrongAvailable: result?['biometricStrong'] == true,
      );
    } on PlatformException {
      return const DeviceAuthCapabilities(
        deviceCredentialAvailable: false,
        biometricStrongAvailable: false,
      );
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
    return File(
      p.join(
        supportDir.path,
        AppIdentifiers.appStorageDirectory,
        'app_lock_store.json',
      ),
    );
  }
}

class UnsupportedAppLockService implements AppLockService {
  const UnsupportedAppLockService();

  @override
  Future<AppUnlockMode> getUnlockMode() async => AppUnlockMode.none;

  @override
  Future<void> setUnlockMode(AppUnlockMode mode) async {}

  @override
  Future<KeystoreAuthKind> keystoreAuthKindForCurrentMode() async {
    return KeystoreAuthKind.plain;
  }

  @override
  Future<bool> canUseDeviceCredential() async => false;

  @override
  Future<bool> canUseBiometric() async => false;

  @override
  Future<DeviceAuthCapabilities> getDeviceAuthCapabilities() async {
    return const DeviceAuthCapabilities(
      deviceCredentialAvailable: false,
      biometricStrongAvailable: false,
    );
  }
}
