import '../../domain/security/unlocked_vault_session.dart';
import 'vault_salvage_models.dart';
import 'vault_repository.dart';

class VaultRepairService {
  const VaultRepairService(this._repository);

  final VaultRepository _repository;

  Future<void> rebuildIndex(UnlockedVaultSession session) =>
      _repository.rebuildIndex(session);

  Future<VaultInspectReport> inspectVaultWithReport(
    UnlockedVaultSession session, {
    VaultRepairProgressCallback? onProgress,
  }) => _repository.inspectVaultWithReport(session, onProgress: onProgress);

  Future<VaultRepairReport> repairVaultWithReport(
    UnlockedVaultSession session, {
    VaultRepairProgressCallback? onProgress,
    String? backupFileName,
  }) => _repository.repairVaultWithReport(
    session,
    onProgress: onProgress,
    backupFileName: backupFileName,
  );

  Future<VaultRepairSummary?> readLastRepairSummary() =>
      _repository.readLastRepairSummary();

  Future<VaultInspectSummary?> readLastInspectSummary() =>
      _repository.readLastInspectSummary();

  Future<int> permanentlyDeleteAbnormalFindings(
    UnlockedVaultSession session, {
    required List<VaultFinding> findings,
  }) => _repository.permanentlyDeleteAbnormalFindings(
    session,
    findings: findings,
  );

  Future<VaultSalvageDraft?> tryCreateSalvageDraft(
    UnlockedVaultSession session, {
    required List<VaultFinding> findings,
  }) => _repository.tryCreateSalvageDraft(session, findings: findings);

  Future<bool> canSalvageFindings(
    UnlockedVaultSession session,
    List<VaultFinding> findings,
  ) => _repository.canSalvageFindings(session, findings);
}
