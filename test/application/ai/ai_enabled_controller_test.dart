import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/infrastructure/ai/ai_settings_store.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/ai/ai_test_helpers.dart';
import '../../helpers/vault/vault_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VaultTestHarness harness;
  late RecoverySetupResult setup;
  late OverviewAiSettingsStore settings;
  late ProviderContainer container;

  ProviderContainer createContainer(AiSettingsStore store) => ProviderContainer(
    overrides: [
      vaultPathStrategyProvider.overrideWithValue(harness.pathStrategy),
      vaultRepositoryProvider.overrideWithValue(harness.repository),
      aiSettingsStoreProvider.overrideWithValue(store),
      editorDraftStoreProvider.overrideWithValue(EmptyEditorDraftStore()),
      userPreferencesProvider.overrideWithValue(
        UserPreferences(
          storageFile: File('${harness.tempDir.path}/preferences.json'),
        ),
      ),
    ],
  );

  setUp(() async {
    harness = await VaultTestHarness.create();
    setup = await harness.repository.setupRecoveryKey();
    settings = OverviewAiSettingsStore();
    container = createContainer(settings);
  });

  tearDown(() async {
    container.dispose();
    await harness.dispose();
  });

  Future<void> unlock() async {
    container.read(appSessionProvider.notifier).activateSession(setup.session);
    await container.read(effectiveAppSessionProvider.future);
    // 讀取為記憶體假資料，等待一輪事件即可完成載入。
    await Future<void>.delayed(Duration.zero);
  }

  test('預設開啟，解鎖後讀入加密 AI 設定中的開關', () async {
    expect(container.read(aiEnabledProvider), isTrue);
    settings.aiEnabled = false;

    await unlock();

    expect(container.read(aiEnabledProvider), isFalse);
  });

  test('切換開關寫入 AI 設定，並在鎖定後保留最後已知值', () async {
    await unlock();

    await container.read(aiEnabledProvider.notifier).setEnabled(false);
    expect(settings.aiEnabled, isFalse);
    expect(container.read(aiEnabledProvider), isFalse);

    await container.read(appSessionProvider.notifier).lock();
    expect(container.read(aiEnabledProvider), isFalse);
  });

  test('未解鎖時不能切換開關', () async {
    await expectLater(
      container.read(aiEnabledProvider.notifier).setEnabled(false),
      throwsStateError,
    );
    expect(container.read(aiEnabledProvider), isTrue);
    expect(settings.aiEnabled, isTrue);
  });

  test('背景讀取舊設定不能覆蓋使用者剛關閉的 AI 開關', () async {
    container.dispose();
    final realStore = AiSettingsStore(
      pathStrategy: harness.pathStrategy,
      cryptoService: LocalCryptoService(),
      repository: harness.repository,
    );
    container = createContainer(realStore);
    await unlock();
    final entered = Completer<void>();
    final release = Completer<void>();
    final blocking = harness.repository.runVaultMutation(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    expect(container.read(aiEnabledProvider), isTrue);
    final saving = container.read(aiEnabledProvider.notifier).setEnabled(false);
    expect(container.read(aiEnabledProvider), isFalse);
    release.complete();
    await blocking;
    await saving;
    expect((await realStore.read(setup.session)).aiEnabled, isFalse);
    expect(container.read(aiEnabledProvider), isFalse);
  });

  test('連續切換都寫入失敗時回到已保存的值，不採用前一次樂觀狀態', () async {
    await unlock();
    final notifier = container.read(aiEnabledProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final release = Completer<void>();
    settings.enabledWriteGate = release.future;
    settings.failEnabledWrites = true;
    final first = expectLater(notifier.setEnabled(false), throwsStateError);
    final second = expectLater(notifier.setEnabled(true), throwsStateError);
    release.complete();
    await Future.wait([first, second]);
    expect(container.read(aiEnabledProvider), settings.aiEnabled);
    expect(container.read(aiEnabledProvider), isTrue);
  });

  test('載入期間切換失敗時使用已讀回的保存值還原，不改用啟動預設值', () async {
    expect(container.read(aiEnabledProvider), isTrue);
    settings.aiEnabled = false;
    final readStarted = Completer<void>();
    final reading = Completer<void>();
    final writing = Completer<void>();
    settings.readStarted = readStarted;
    settings.readGate = reading.future;
    settings.enabledWriteGate = writing.future;
    settings.failEnabledWrites = true;
    await unlock();
    await readStarted.future;
    settings.readStarted = null;
    expect(container.read(aiEnabledProvider), isTrue);
    final saving = expectLater(
      container.read(aiEnabledProvider.notifier).setEnabled(false),
      throwsStateError,
    );
    reading.complete();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(aiEnabledProvider), isFalse);
    writing.complete();
    await saving;
    expect(container.read(aiEnabledProvider), settings.aiEnabled);
    expect(container.read(aiEnabledProvider), isFalse);
  });

  test('鎖定期間寫入失敗時保留樂觀值，重新解鎖後讀回已保存值', () async {
    expect(container.read(aiEnabledProvider), isTrue);
    await unlock();
    final release = Completer<void>();
    settings.enabledWriteGate = release.future;
    settings.failEnabledWrites = true;
    final saving = expectLater(
      container.read(aiEnabledProvider.notifier).setEnabled(false),
      throwsStateError,
    );
    expect(container.read(aiEnabledProvider), isFalse);

    await container.read(appSessionProvider.notifier).lock();
    release.complete();
    await saving;
    expect(settings.aiEnabled, isTrue);
    expect(container.read(aiEnabledProvider), isFalse);

    await unlock();
    expect(container.read(aiEnabledProvider), settings.aiEnabled);
    expect(container.read(aiEnabledProvider), isTrue);
  });

  test('前一次切換保存成功但最後一次失敗，還原最後已提交的值', () async {
    await unlock();
    final notifier = container.read(aiEnabledProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final release = Completer<void>();
    settings.enabledWriteGate = release.future;
    final first = notifier.setEnabled(false);
    settings.failEnabledWrites = true;
    final second = expectLater(notifier.setEnabled(true), throwsStateError);
    release.complete();
    await Future.wait([first, second]);
    expect(container.read(aiEnabledProvider), settings.aiEnabled);
    expect(container.read(aiEnabledProvider), isFalse);
  });

  test('舊工作階段的寫入失敗不能改變重新解鎖後的開關', () async {
    await unlock();
    final notifier = container.read(aiEnabledProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final release = Completer<void>();
    settings.enabledWriteGate = release.future;
    settings.failEnabledWrites = true;
    final saving = expectLater(notifier.setEnabled(false), throwsStateError);
    await container.read(appSessionProvider.notifier).lock();
    settings.aiEnabled = false;
    container
        .read(appSessionProvider.notifier)
        .activateSession(setup.session.copyWith());
    await container.read(effectiveAppSessionProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(aiEnabledProvider), isFalse);
    release.complete();
    await saving;
    expect(container.read(aiEnabledProvider), isFalse);
  });
}
