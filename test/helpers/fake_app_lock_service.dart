import 'package:quill_lock_diary/infrastructure/security/app_lock_service.dart';

class FakeAppLockService implements AppLockService {
  FakeAppLockService({this.biometricEnabled = false});

  bool biometricEnabled;

  @override
  Future<bool> isBiometricLockEnabled() async => biometricEnabled;

  @override
  Future<bool> isSessionLocked() async => false;

  @override
  Future<void> lock() async {}

  @override
  Future<void> setBiometricLockEnabled(bool enabled) async {
    biometricEnabled = enabled;
  }

  @override
  Future<bool> unlock() async => true;
}
