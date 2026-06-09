import '../shared/value_objects.dart';

/// In-memory proof that the current process can access one vault.
///
/// A session may be restored by trusted-device material or by a Recovery Key.
/// Keep instances short-lived and avoid persisting [recoveryWrapKey].
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
