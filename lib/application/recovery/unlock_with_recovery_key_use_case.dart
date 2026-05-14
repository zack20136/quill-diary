import '../../domain/security/unlocked_vault_session.dart';
import '../../infrastructure/storage/vault_repository.dart';

class UnlockWithRecoveryKeyUseCase {
  const UnlockWithRecoveryKeyUseCase(this._repository);

  final VaultRepository _repository;

  Future<UnlockedVaultSession> call(String recoveryKey) {
    return _repository.unlockWithRecoveryKey(recoveryKey);
  }
}
