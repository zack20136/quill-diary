abstract class AppLockService {
  Future<bool> unlock();

  Future<void> lock();
}
