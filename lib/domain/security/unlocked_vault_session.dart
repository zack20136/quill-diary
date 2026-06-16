import '../shared/value_objects.dart';

/// 證明目前行程可存取某個 vault 的記憶體內憑證。
///
/// session 可透過可信裝置材料或 Recovery Key 還原。
/// 實例應短生命週期，避免持久化 [recoveryWrapKey]。
class UnlockedVaultSession {
  const UnlockedVaultSession({
    required this.vaultId,
    required this.trustedDevice,
    this.recoveryWrapKey,
    this.deviceSlotId,
  });

  final VaultId vaultId;
  final bool trustedDevice;
  final List<int>? recoveryWrapKey;
  final DeviceSlotId? deviceSlotId;

  bool get canUseRecovery => recoveryWrapKey != null;

  UnlockedVaultSession copyWith({
    VaultId? vaultId,
    bool? trustedDevice,
    List<int>? recoveryWrapKey,
    DeviceSlotId? deviceSlotId,
    bool clearRecoveryWrapKey = false,
    bool clearDeviceSlotId = false,
  }) {
    return UnlockedVaultSession(
      vaultId: vaultId ?? this.vaultId,
      trustedDevice: trustedDevice ?? this.trustedDevice,
      recoveryWrapKey: clearRecoveryWrapKey
          ? null
          : (recoveryWrapKey ?? this.recoveryWrapKey),
      deviceSlotId: clearDeviceSlotId
          ? null
          : (deviceSlotId ?? this.deviceSlotId),
    );
  }
}
