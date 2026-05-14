import '../shared/value_objects.dart';

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
      recoveryWrapKey: clearRecoveryWrapKey ? null : (recoveryWrapKey ?? this.recoveryWrapKey),
      deviceSlotId: clearDeviceSlotId ? null : (deviceSlotId ?? this.deviceSlotId),
    );
  }
}
