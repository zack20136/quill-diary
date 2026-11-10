import 'dart:io';

import 'package:flutter/services.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_policy.dart';
import 'package:quill_diary/infrastructure/storage/shared/app_support_string_map.dart';
import 'package:quill_diary/shared/app_identifiers.dart';

/// 在日記庫外持久化使用者偏好的可信裝置解鎖政策。
abstract class AppLockService {
  Future<AppUnlockMode> getUnlockMode();

  Future<void> setUnlockMode(AppUnlockMode mode);

  Future<KeystoreAuthKind> keystoreAuthKindForCurrentMode();

  Future<bool> canUseDeviceCredential();

  Future<bool> canUseBiometric();

  Future<DeviceAuthCapabilities> getDeviceAuthCapabilities();
}

/// 檔案型 App 鎖定偏好，外加原生 Android 憑證能力檢查。
class LocalAppLockService implements AppLockService {
  LocalAppLockService()
    : _store = AppSupportStringMap(fileName: 'app_lock_store.json');

  static const String _unlockModeKey = 'app_lock.unlock_mode';
  final AppSupportStringMap _store;

  static const MethodChannel _deviceKeyChannel = MethodChannel(
    AppIdentifiers.deviceKeyChannel,
  );

  @override
  Future<AppUnlockMode> getUnlockMode() async {
    return AppUnlockModeStorage.fromStorage(
      (await _store.load())[_unlockModeKey],
    );
  }

  @override
  Future<void> setUnlockMode(AppUnlockMode mode) =>
      _store.update({_unlockModeKey: mode.storageValue});

  @override
  Future<KeystoreAuthKind> keystoreAuthKindForCurrentMode() async {
    return requireKeystoreAuthKindForMode(
      appLock: this,
      mode: await getUnlockMode(),
    );
  }

  @override
  Future<bool> canUseDeviceCredential() async {
    final DeviceAuthCapabilities capabilities =
        await getDeviceAuthCapabilities();
    return capabilities.deviceCredentialAvailable;
  }

  @override
  Future<bool> canUseBiometric() async {
    final DeviceAuthCapabilities capabilities =
        await getDeviceAuthCapabilities();
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
      final Map<Object?, Object?>? result = await _deviceKeyChannel
          .invokeMapMethod<Object?, Object?>('getDeviceAuthCapabilities');
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
