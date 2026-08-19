import '../../domain/security/unlocked_vault_session.dart';
import 'vault_repository.dart';

class VaultRepairService {
  const VaultRepairService(this._repository);

  final VaultRepository _repository;

  Future<void> rebuildIndex(UnlockedVaultSession session) =>
      _repository.rebuildIndex(session);

  Future<VaultRepairReport> repairVaultWithReport(
    UnlockedVaultSession session, {
    VaultRepairProgressCallback? onProgress,
  }) => _repository.repairVaultWithReport(session, onProgress: onProgress);

  Future<VaultRepairSummary?> readLastRepairSummary() =>
      _repository.readLastRepairSummary();
}
