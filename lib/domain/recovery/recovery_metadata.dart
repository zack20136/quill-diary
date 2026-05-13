import '../shared/value_objects.dart';

class RecoveryMetadata {
  const RecoveryMetadata({
    required this.vaultId,
    required this.recoveryEnabled,
    required this.recoveryKeyVersion,
    required this.recoveryKeyHint,
    required this.createdAt,
    required this.kdfAlgorithm,
  });

  final VaultId vaultId;
  final bool recoveryEnabled;
  final int recoveryKeyVersion;
  final String recoveryKeyHint;
  final DateTime createdAt;
  final String kdfAlgorithm;
}
