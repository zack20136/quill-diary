import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/features/settings/providers/settings_providers.dart';
import 'package:quill_lock_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_lock_diary/shared/providers/core_providers.dart';

import '../../helpers/fake_vault_transfer_service.dart';

void main() {
  ProviderContainer buildContainer(FakeVaultTransferService transferService) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        vaultTransferServiceProvider.overrideWithValue(transferService),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  DriveConnectionState? readData(AsyncValue<DriveConnectionState> value) {
    return value.when(
      data: (DriveConnectionState data) => data,
      loading: () => null,
      error: (_, _) => null,
    );
  }

  test('初次讀取只檢查一次 Google Drive 連線狀態', () async {
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      connectionState: const DriveConnectionState.disconnected(),
    );
    final ProviderContainer container = buildContainer(transferService);
    final ProviderSubscription<AsyncValue<DriveConnectionState>> subscription =
        container.listen(
      settingsDriveConnectionProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final DriveConnectionState first =
        await container.read(settingsDriveConnectionProvider.future);
    final AsyncValue<DriveConnectionState> second =
        container.read(settingsDriveConnectionProvider);

    expect(first.isConnected, isFalse);
    expect(readData(second)?.isConnected, isFalse);
    expect(transferService.isConnectedCalls, 1);
  });

  test('connect 後重新讀取會得到已連結帳號資訊', () async {
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      connectionStates: const <DriveConnectionState>[
        DriveConnectionState.disconnected(),
        DriveConnectionState(
          isConnected: true,
          email: 'writer@example.com',
          displayName: 'Writer',
        ),
      ],
    );
    final ProviderContainer container = buildContainer(transferService);
    final ProviderSubscription<AsyncValue<DriveConnectionState>> subscription =
        container.listen(
      settingsDriveConnectionProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      (await container.read(settingsDriveConnectionProvider.future)).isConnected,
      isFalse,
    );

    await transferService.connectGoogleDrive();
    container.invalidate(settingsDriveConnectionProvider);
    final DriveConnectionState connected =
        await container.read(settingsDriveConnectionProvider.future);

    expect(connected.isConnected, isTrue);
    expect(connected.email, 'writer@example.com');
    expect(connected.displayName, 'Writer');
    expect(readData(container.read(settingsDriveConnectionProvider))?.email, 'writer@example.com');
    expect(transferService.connectCalls, 1);
    expect(transferService.reconnectCalls, 0);
    expect(transferService.isConnectedCalls, 2);
  });

  test('reconnect 後重新讀取會更新為最新帳號資訊', () async {
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      connectionStates: const <DriveConnectionState>[
        DriveConnectionState(
          isConnected: true,
          email: 'before@example.com',
          displayName: 'Before',
        ),
        DriveConnectionState(
          isConnected: true,
          email: 'after@example.com',
          displayName: 'After',
        ),
      ],
    );
    final ProviderContainer container = buildContainer(transferService);
    final ProviderSubscription<AsyncValue<DriveConnectionState>> subscription =
        container.listen(
      settingsDriveConnectionProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      (await container.read(settingsDriveConnectionProvider.future)).email,
      'before@example.com',
    );

    await transferService.connectGoogleDrive(reconnect: true);
    container.invalidate(settingsDriveConnectionProvider);
    final DriveConnectionState reconnected =
        await container.read(settingsDriveConnectionProvider.future);

    expect(reconnected.isConnected, isTrue);
    expect(reconnected.email, 'after@example.com');
    expect(reconnected.displayName, 'After');
    expect(transferService.connectCalls, 0);
    expect(transferService.reconnectCalls, 1);
    expect(transferService.isConnectedCalls, 2);
  });
}
