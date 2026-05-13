import 'dart:io';

import '../../infrastructure/storage/vault_repository.dart';

class CreateBackupSnapshotUseCase {
  const CreateBackupSnapshotUseCase(this._repository);

  final VaultRepository _repository;

  Future<File> call() {
    return _repository.createBackupSnapshot();
  }
}
