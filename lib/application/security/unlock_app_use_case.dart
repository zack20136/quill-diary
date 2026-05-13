class UnlockAppUseCase {
  const UnlockAppUseCase();

  Future<bool> call() async {
    // TODO(zack): validate PIN or biometrics and open a secure session.
    return true;
  }
}
