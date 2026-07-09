import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../security/app_unlock_mode.dart';
import 'vault_repository.dart';

class VaultRecoveryService {
  const VaultRecoveryService(this._repository);

  final VaultRepository _repository;

  Future<void> initialize() => _repository.initialize();

  Future<bool> hasVault() => _repository.hasVault();

  Future<RecoveryMetadata?> readRecoveryMetadata() =>
      _repository.readRecoveryMetadata();

  Future<bool> hasTrustedDeviceAccess() => _repository.hasTrustedDeviceAccess();

  Future<UnlockedVaultSession> openTrustedSession() =>
      _repository.openTrustedSession();

  Future<UnlockedVaultSession> openTrustedSessionEnsuringKeystore() =>
      _repository.openTrustedSessionEnsuringKeystore();

  Future<RecoverySetupResult> setupRecoveryKey() =>
      _repository.setupRecoveryKey();

  Future<RecoverySetupResult> rotateRecoveryKey(UnlockedVaultSession session) =>
      _repository.rotateRecoveryKey(session);

  Future<UnlockedVaultSession> unlockWithRecoveryKey(String recoveryKey) =>
      _repository.unlockWithRecoveryKey(recoveryKey);

  Future<void> ensureIndexReady(UnlockedVaultSession session) =>
      _repository.ensureIndexReady(session);

  Future<UnlockedVaultSession> ensureKeystoreMatchesUnlockMode(
    UnlockedVaultSession session, {
    AppUnlockMode? targetMode,
  }) => _repository.ensureKeystoreMatchesUnlockMode(
    session,
    targetMode: targetMode,
  );

  Future<void> closeUnlockedResources() => _repository.closeUnlockedResources();

  Future<void> clearTrustedDeviceAccess() =>
      _repository.clearTrustedDeviceAccess();
}
