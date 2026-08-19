import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  late VaultTestHarness harness;
  late RecoverySetupResult setup;
  late _FailingMarkdownCryptoService cryptoService;

  setUp(() async {
    cryptoService = _FailingMarkdownCryptoService();
    harness = await VaultTestHarness.create(cryptoService: cryptoService);
    setup = await harness.repository.setupRecoveryKey();
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<String> assetPath(DateOnly date, AssetAttachment attachment) {
    return harness.pathStrategy.assetAbsolutePath(
      date: date,
      assetId: attachment.id,
      extension: 'jpg',
    );
  }

  test('新附件排到既有附件前方後重新載入仍保留順序', () async {
    final DiaryEntry original = await harness.repository.saveEntry(
      setup.session,
      _entry(
        vaultId: setup.session.vaultId,
        attachmentIds: const <AssetId>['saved-image'],
      ),
      pendingAttachments: <PendingAttachment>[_pending('saved-image', 1)],
    );

    final DiaryEntry reordered = await harness.repository.saveEntry(
      setup.session,
      original.copyWith(
        attachmentIds: const <AssetId>['pending-image', 'saved-image'],
      ),
      pendingAttachments: <PendingAttachment>[_pending('pending-image', 2)],
    );

    final DiaryEntry? loaded = await harness.repository.loadEntry(
      setup.session,
      original.id,
    );
    final attachments = await harness.repository.loadAttachments(original.id);

    expect(reordered.attachmentIds, <AssetId>['pending-image', 'saved-image']);
    expect(loaded?.attachmentIds, <AssetId>['pending-image', 'saved-image']);
    expect(attachments.map((attachment) => attachment.id), <AssetId>[
      'pending-image',
      'saved-image',
    ]);
  });

  test('暫存附件 ID 撞到既有附件時不會刪除既有附件', () async {
    final DiaryEntry original = await harness.repository.saveEntry(
      setup.session,
      _entry(
        vaultId: setup.session.vaultId,
        attachmentIds: const <AssetId>['saved-image'],
      ),
      pendingAttachments: <PendingAttachment>[_pending('saved-image', 1)],
    );

    await expectLater(
      harness.repository.saveEntry(
        setup.session,
        original.copyWith(attachmentIds: const <AssetId>['saved-image']),
        pendingAttachments: <PendingAttachment>[_pending('saved-image', 2)],
      ),
      throwsArgumentError,
    );

    final attachments = await harness.repository.loadAttachments(original.id);
    expect(attachments.map((attachment) => attachment.id), <AssetId>[
      'saved-image',
    ]);
  });

  test('重複的暫存附件 ID 會在寫入前被拒絕', () async {
    await expectLater(
      harness.repository.saveEntry(
        setup.session,
        _entry(vaultId: setup.session.vaultId),
        pendingAttachments: <PendingAttachment>[
          _pending('duplicate', 1),
          _pending('duplicate', 2),
        ],
      ),
      throwsArgumentError,
    );

    expect(await harness.repository.loadAttachments('entry-1'), isEmpty);
  });

  test('匯入未提供新附件順序時會依輸入順序附加', () async {
    final DiaryEntry saved = await harness.repository.saveEntry(
      setup.session,
      _entry(vaultId: setup.session.vaultId),
      pendingAttachments: <PendingAttachment>[
        _pending('first', 1),
        _pending('second', 2),
      ],
    );

    expect(saved.attachmentIds, <AssetId>['first', 'second']);
  });

  test('日記換日期成功後附件會移到新日期並清除舊檔', () async {
    final DiaryEntry original = await harness.repository.saveEntry(
      setup.session,
      _entry(
        vaultId: setup.session.vaultId,
        attachmentIds: const <AssetId>['saved-image'],
      ),
      pendingAttachments: <PendingAttachment>[_pending('saved-image', 1)],
    );
    final AssetAttachment attachment =
        (await harness.repository.loadAttachments(original.id)).single;
    final String oldPath = await assetPath(original.date, attachment);
    const DateOnly newDate = DateOnly('2025-08-18');
    final String newPath = await assetPath(newDate, attachment);

    await harness.repository.saveEntry(
      setup.session,
      original.copyWith(date: newDate),
    );

    expect(File(oldPath).existsSync(), isFalse);
    expect(File(newPath).existsSync(), isTrue);
    expect(
      (await harness.repository.loadEntry(
        setup.session,
        original.id,
      ))?.date.value,
      newDate.value,
    );
  });

  test('日記換日期儲存失敗時保留舊日記與所有舊附件', () async {
    final DiaryEntry original = await harness.repository.saveEntry(
      setup.session,
      _entry(
        vaultId: setup.session.vaultId,
        attachmentIds: const <AssetId>['kept-image', 'removed-image'],
      ),
      pendingAttachments: <PendingAttachment>[
        _pending('kept-image', 1),
        _pending('removed-image', 2),
      ],
    );
    final List<AssetAttachment> attachments = await harness.repository
        .loadAttachments(original.id);
    final List<String> oldPaths = <String>[
      for (final AssetAttachment attachment in attachments)
        await assetPath(original.date, attachment),
    ];
    cryptoService.failNextMarkdownEncryption = true;

    await expectLater(
      harness.repository.saveEntry(
        setup.session,
        original.copyWith(
          date: const DateOnly('2025-08-18'),
          attachmentIds: const <AssetId>['kept-image'],
        ),
      ),
      throwsStateError,
    );

    expect(oldPaths.every((String path) => File(path).existsSync()), isTrue);
    final DiaryEntry? loaded = await harness.repository.loadEntry(
      setup.session,
      original.id,
    );
    expect(loaded?.date.value, original.date.value);
    expect(loaded?.attachmentIds, <AssetId>['kept-image', 'removed-image']);
  });
}

DiaryEntry _entry({
  required String vaultId,
  List<AssetId> attachmentIds = const <AssetId>[],
}) {
  return DiaryEntry(
    id: 'entry-1',
    vaultId: vaultId,
    title: '附件排序',
    date: const DateOnly('2026-08-18'),
    createdAt: DateTime(2026, 8, 18, 8),
    updatedAt: DateTime(2026, 8, 18, 8),
    markdownBody: '內容',
    attachmentIds: attachmentIds,
  );
}

PendingAttachment _pending(AssetId assetId, int byte) {
  return PendingAttachment(
    assetId: assetId,
    bytes: Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, byte]),
    mimeType: 'image/jpeg',
    originalFilename: '$assetId.jpg',
  );
}

class _FailingMarkdownCryptoService extends LocalCryptoService {
  bool failNextMarkdownEncryption = false;

  @override
  Future<EncryptionResult> encryptMarkdown({
    required String documentId,
    required String vaultId,
    required String markdown,
    required List<int> recoveryWrapKey,
    required KdfDescriptor recoverySlotKdf,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (failNextMarkdownEncryption) {
      failNextMarkdownEncryption = false;
      throw StateError('模擬日記加密失敗');
    }
    return super.encryptMarkdown(
      documentId: documentId,
      vaultId: vaultId,
      markdown: markdown,
      recoveryWrapKey: recoveryWrapKey,
      recoverySlotKdf: recoverySlotKdf,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
