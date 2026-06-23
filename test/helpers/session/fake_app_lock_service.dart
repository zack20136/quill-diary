import 'package:quill_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';
import 'package:quill_diary/infrastructure/security/unlock_mode_policy.dart';

class FakeAppLockService implements AppLockService {
  FakeAppLockService({
    AppUnlockMode unlockMode = AppUnlockMode.none,
    this.canUseDeviceCredentialResult = true,
    this.canUseBiometricResult = true,
  }) : _unlockMode = unlockMode;

  AppUnlockMode _unlockMode;
  bool canUseDeviceCredentialResult;
  bool canUseBiometricResult;

  @override
  Future<AppUnlockMode> getUnlockMode() async => _unlockMode;

  @override
  Future<void> setUnlockMode(AppUnlockMode mode) async {
    _unlockMode = mode;
  }

  @override
  Future<KeystoreAuthKind> keystoreAuthKindForCurrentMode() async {
    return requireKeystoreAuthKindForMode(appLock: this, mode: _unlockMode);
  }

  @override
  Future<bool> canUseDeviceCredential() async => canUseDeviceCredentialResult;

  @override
  Future<bool> canUseBiometric() async => canUseBiometricResult;

  @override
  Future<DeviceAuthCapabilities> getDeviceAuthCapabilities() async {
    return DeviceAuthCapabilities(
      deviceCredentialAvailable: canUseDeviceCredentialResult,
      biometricStrongAvailable: canUseBiometricResult,
    );
  }
}
