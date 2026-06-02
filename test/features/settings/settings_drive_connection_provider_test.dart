import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/features/settings/providers/settings_providers.dart';
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

  bool? readData(AsyncValue<bool> value) {
    return value.when(
      data: (bool data) => data,
      loading: () => null,
      error: (_, _) => null,
    );
  }

  test('初次讀取只檢查一次 Google Drive 連線狀態', () async {
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      isConnectedResult: false,
    );
    final ProviderContainer container = buildContainer(transferService);
    final ProviderSubscription<AsyncValue<bool>> subscription = container.listen(
      settingsDriveConnectionProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final bool first = await container.read(settingsDriveConnectionProvider.future);
    final AsyncValue<bool> second = container.read(settingsDriveConnectionProvider);

    expect(first, isFalse);
    expect(readData(second), isFalse);
    expect(transferService.isConnectedCalls, 1);
  });

  test('connect 後重新讀取狀態並切到已連線', () async {
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      isConnectedValues: <bool>[false, true],
    );
    final ProviderContainer container = buildContainer(transferService);
    final ProviderSubscription<AsyncValue<bool>> subscription = container.listen(
      settingsDriveConnectionProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(await container.read(settingsDriveConnectionProvider.future), isFalse);

    await transferService.connectGoogleDrive();
    container.invalidate(settingsDriveConnectionProvider);
    expect(await container.read(settingsDriveConnectionProvider.future), isTrue);

    expect(readData(container.read(settingsDriveConnectionProvider)), isTrue);
    expect(transferService.connectCalls, 1);
    expect(transferService.reconnectCalls, 0);
    expect(transferService.isConnectedCalls, 2);
  });

  test('reconnect 後重新讀取狀態並維持已連線', () async {
    final FakeVaultTransferService transferService = FakeVaultTransferService(
      isConnectedValues: <bool>[true, true],
    );
    final ProviderContainer container = buildContainer(transferService);
    final ProviderSubscription<AsyncValue<bool>> subscription = container.listen(
      settingsDriveConnectionProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(await container.read(settingsDriveConnectionProvider.future), isTrue);

    await transferService.connectGoogleDrive(reconnect: true);
    container.invalidate(settingsDriveConnectionProvider);
    expect(await container.read(settingsDriveConnectionProvider.future), isTrue);

    expect(readData(container.read(settingsDriveConnectionProvider)), isTrue);
    expect(transferService.connectCalls, 0);
    expect(transferService.reconnectCalls, 1);
    expect(transferService.isConnectedCalls, 2);
  });
}
