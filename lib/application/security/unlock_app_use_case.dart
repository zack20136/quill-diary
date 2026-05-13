import '../../infrastructure/security/app_lock_service.dart';

class UnlockAppUseCase {
  const UnlockAppUseCase(this._appLockService);

  final AppLockService _appLockService;

  Future<bool> call() {
    return _appLockService.unlock();
  }
}
