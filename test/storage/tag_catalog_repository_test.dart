import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/tag_styles_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../helpers/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;

  Future<void> persistZhTwPreference() {
    // Make the one-time default-tag seed deterministic for this catalog test.
    return UserPreferences(
      storageFile: File('${harness.tempDir.path}/app_preferences.json'),
    ).setAppLocale(AppLanguage.zh);
  }

  setUp(() async {
    harness = await VaultTestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('setupRecoveryKey 後會 seed 預設標籤與語意色', () async {
    await persistZhTwPreference();
    await harness.repository.setupRecoveryKey();

    final List<TagCatalogItem> catalog = await harness.repository
        .listTagCatalog();
    expect(catalog.map((TagCatalogItem item) => item.label), <String>[
      '日常',
      '心情',
      '心得',
      '筆記',
      '反思',
      '靈感',
      '計畫',
      '目標',
      '工作',
      '學習',
      '人際',
      '家庭',
      '健康',
      '感謝',
    ]);
    expect(
      TagStylesStore.toAccentMap(catalog)[normalizeText('學習')],
      0xFF20C997,
    );
  });

  test('ensureIndexReady 在空 catalog 時 seed 預設標籤', () async {
    await persistZhTwPreference();
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();
    await TagStylesStore(harness.pathStrategy).write(const <TagCatalogItem>[]);

    final UnlockedVaultSession session = await harness.repository
        .unlockWithRecoveryKey(setup.recoveryKey);
    await harness.repository.ensureIndexReady(session);

    final List<TagCatalogItem> catalog = await harness.repository
        .listTagCatalog();
    expect(catalog.map((TagCatalogItem item) => item.label), contains('日常'));
    expect(catalog.map((TagCatalogItem item) => item.label), contains('工作'));
  });

  test('未使用標籤也會保留在標籤目錄', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();

    await harness.repository.upsertTagCatalogItem(
      '臨時想法',
      accentArgb: 0xFF123456,
    );
    await harness.repository.closeUnlockedResources();

    final UnlockedVaultSession session = await harness.repository
        .unlockWithRecoveryKey(setup.recoveryKey);
    await harness.repository.ensureIndexReady(session);

    final List<TagCatalogItem> catalog = await harness.repository
        .listTagCatalog();
    expect(
      catalog.any(
        (TagCatalogItem item) =>
            item.label == '臨時想法' && item.accentArgb == 0xFF123456,
      ),
      isTrue,
    );
  });

  test('renameTagCatalogItem 會更新 catalog 與日記條目', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();

    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-01'),
        createdAt: DateTime.parse('2026-06-01T10:00:00'),
        updatedAt: DateTime.parse('2026-06-01T10:00:00'),
        markdownBody: 'body',
        tags: const <String>['工作'],
      ),
    );

    await harness.repository.renameTagCatalogItem(
      setup.session,
      fromLabel: '工作',
      toLabel: '職場',
      accentArgb: 0xFF228BE6,
    );

    final List<TagCatalogItem> catalog = await harness.repository
        .listTagCatalog();
    expect(catalog.any((TagCatalogItem item) => item.label == '職場'), isTrue);
    expect(catalog.any((TagCatalogItem item) => item.label == '工作'), isFalse);

    final List<EntryIndexRecord> entries = await harness.repository
        .listEntries();
    expect(entries.single.tags, <String>['職場']);
    expect(
      TagStylesStore.toAccentMap(catalog)[normalizeText('職場')],
      0xFF228BE6,
    );
  });

  test('saveEntry 會將日記標籤寫入目錄', () async {
    final RecoverySetupResult setup = await harness.repository
        .setupRecoveryKey();

    await harness.repository.saveEntry(
      setup.session,
      DiaryEntry(
        id: generateEntryId(),
        vaultId: setup.session.vaultId,
        date: const DateOnly('2026-06-01'),
        createdAt: DateTime.parse('2026-06-01T10:00:00'),
        updatedAt: DateTime.parse('2026-06-01T10:00:00'),
        markdownBody: 'body',
        tags: const <String>['手打標籤'],
      ),
    );

    final List<TagCatalogItem> catalog = await harness.repository
        .listTagCatalog();
    expect(catalog.any((TagCatalogItem item) => item.label == '手打標籤'), isTrue);
  });
}
