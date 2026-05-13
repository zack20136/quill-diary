import '../../infrastructure/storage/vault_repository.dart';

class SetupRecoveryKeyUseCase {
  const SetupRecoveryKeyUseCase(this._repository);

  final VaultRepository _repository;

  Future<String> call() {
    return _repository.setupRecoveryKey();
  }
}
