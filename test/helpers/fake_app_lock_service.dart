import 'package:quill_lock_diary/infrastructure/security/app_lock_service.dart';
import 'package:quill_lock_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_lock_diary/infrastructure/security/keystore_unlock_policy.dart';

class FakeAppLockService implements AppLockService {
  FakeAppLockService({
    AppUnlockMode unlockMode = AppUnlockMode.none,
    this.canUseDeviceCredentialResult = true,
  }) : _unlockMode = unlockMode;

  AppUnlockMode _unlockMode;
  bool canUseDeviceCredentialResult;

  @override
  Future<AppUnlockMode> getUnlockMode() async => _unlockMode;

  @override
  Future<void> setUnlockMode(AppUnlockMode mode) async {
    _unlockMode = mode;
  }

  @override
  Future<KeystoreAuthKind> keystoreAuthKindForCurrentMode() async {
    return keystoreAuthFor(_unlockMode);
  }

  @override
  Future<bool> canUseDeviceCredential() async => canUseDeviceCredentialResult;
}
