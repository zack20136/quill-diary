import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/recovery_key_identity.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/recovery_rotation_record.dart';
import 'package:quill_diary/infrastructure/storage/shared/archive_extract.dart';
import 'package:quill_diary/infrastructure/storage/vault_state_keys.dart';

import '../../helpers/vault/vault_test_harness.dart';

void main() {
  test('輪替紀錄拒絕損壞的提醒快照，仍可讀歷史無快照紀錄', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final metadata = (await harness.repository.readRecoveryMetadata())!
        .toJson();
    final record = <String, Object?>{
      'old_metadata': metadata,
      'new_metadata': metadata,
      'new_recovery_key': setup.recoveryKey,
    };
    RecoveryRotationRecord decode() =>
        RecoveryRotationRecord.decode(utf8.encode(jsonEncode(record)));

    expect(decode().hasBackupRequirementSnapshot, isFalse);
    record['previous_backup_requirement'] = null;
    expect(decode().hasBackupRequirementSnapshot, isTrue);
    record['previous_backup_requirement'] = {'vault_id': 'vault'};
    expect(decode, throwsFormatException);
  });

  late Directory root;
  late File file;
  late BackupStatusStore store;
  final oldIdentity = RecoveryKeyIdentity(
    vaultId: 'vault',
    kdfFingerprint: 'a' * 64,
  );
  final newIdentity = RecoveryKeyIdentity(
    vaultId: 'vault',
    kdfFingerprint: 'b' * 64,
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('quill_backup_requirement_');
    file = File('${root.path}/backup_status.json');
    store = BackupStatusStore(storageFile: file);
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  for (final action in BackupStatusAction.values) {
    test('$action 只有目前世代的一般備份完成可解除提醒且跨重啟保留', () async {
      Future<void> complete(
        RecoveryKeyIdentity? identity,
        VaultBackupPurpose? purpose, {
        String jobId = 'job',
      }) => switch (action) {
        BackupStatusAction.localBackup => store.recordLocalBackupSuccess(
          identity: identity,
          purpose: purpose,
        ),
        BackupStatusAction.externalExport => store.recordExternalExportSuccess(
          identity: identity,
          purpose: purpose,
        ),
        BackupStatusAction.driveUpload => store.recordDriveUploadSuccess(
          identity: identity,
          purpose: purpose,
          jobId: jobId,
        ),
      };
      await store.setBackupRequirement(newIdentity);
      await complete(oldIdentity, VaultBackupPurpose.normal);
      await complete(newIdentity, VaultBackupPurpose.preservation);
      await complete(null, null);
      expect(
        (await BackupStatusStore(
          storageFile: file,
        ).read()).requiredBackupIdentity,
        newIdentity,
      );
      await complete(newIdentity, VaultBackupPurpose.normal, jobId: 'new-job');
      expect(
        (await BackupStatusStore(
          storageFile: file,
        ).read()).requiredBackupIdentity,
        isNull,
      );
    });
  }
  test('輪替中斷回復舊世代時保留原有提醒，提交新世代時要求新備份', () async {
    await store.setBackupRequirement(oldIdentity);
    await store.beginRecoveryRotation(oldIdentity, newIdentity);
    store = BackupStatusStore(storageFile: file);
    await store.reconcileRecoveryRotation(oldIdentity);
    expect((await store.read()).requiredBackupIdentity, oldIdentity);
    await store.beginRecoveryRotation(oldIdentity, newIdentity);
    await store.recordDriveUploadSuccess(
      jobId: 'old-during-rotation',
      identity: oldIdentity,
      purpose: VaultBackupPurpose.normal,
    );
    store = BackupStatusStore(storageFile: file);
    await store.reconcileRecoveryRotation(oldIdentity);
    expect((await store.read()).requiredBackupIdentity, isNull);
    await store.beginRecoveryRotation(oldIdentity, newIdentity);
    store = BackupStatusStore(storageFile: file);
    await store.reconcileRecoveryRotation(newIdentity);
    expect((await store.read()).requiredBackupIdentity, newIdentity);
    expect((await store.read()).pendingRecoveryRotation, isNull);
  });
  test('提醒狀態損壞拒絕覆寫，原檔保留且修復後可重試記錄', () async {
    await store.setBackupRequirement(newIdentity);
    final original = await file.readAsString();
    final data = jsonDecode(original) as Map<String, dynamic>;
    (data['recovery_backup'] as Map)['required_identity'] = true;
    final corrupt = jsonEncode(data);
    await file.writeAsString(corrupt);
    await expectLater(
      store.recordLocalBackupSuccess(
        identity: newIdentity,
        purpose: VaultBackupPurpose.normal,
      ),
      throwsFormatException,
    );
    expect(await file.readAsString(), corrupt);
    await file.writeAsString(original);
    await store.recordLocalBackupSuccess(
      identity: newIdentity,
      purpose: VaultBackupPurpose.normal,
    );
    expect((await store.read()).requiredBackupIdentity, isNull);
  });
  test('備份提醒損壞不阻擋可信解鎖與日記讀寫', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final entryId = await harness.saveSimpleEntry(setup, title: '仍可開啟');
    final statusFile = File(
      '${(await harness.pathStrategy.appRootDirectory()).path}/backup_status.json',
    );
    const corrupt = '{"recovery_backup":true}';
    await statusFile.writeAsString(corrupt);
    await harness.repository.closeUnlockedResources();
    final session = await harness.repository.openTrustedSession();
    expect(
      (await harness.repository.loadEntry(session, entryId))!.title,
      '仍可開啟',
    );
    await harness.repository.saveEntry(
      session,
      (await harness.repository.loadEntry(session, entryId))!,
    );
    await expectLater(harness.rotateRecoveryKey(session), throwsStateError);
    expect(
      await harness.indexDatabaseManager.requireOpen().getAppValue(
        kRewrapInProgressKey,
      ),
      isNot('1'),
    );
    expect(
      (await harness.repository.readRecoveryMetadata())!.recoveryKeyHint,
      setup.recoveryKey.substring(setup.recoveryKey.length - 4),
    );
    expect(await statusFile.readAsString(), corrupt);
    await expectLater(
      BackupStatusStore(storageFile: statusFile).read(),
      throwsFormatException,
    );
  });
  test('輪替後提醒綁定實際 ZIP，舊上傳不解除且加密標籤仍可讀', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final initial = await harness.repository.setupRecoveryKey();
    await harness.repository.upsertTagCatalogItem('世代標籤');
    final old = await RecoveryKeyIdentity.fromMetadata(
      (await harness.repository.readRecoveryMetadata())!,
    );
    final rotated = await harness.rotateRecoveryKey(initial.session);
    final status = BackupStatusStore(pathStrategy: harness.pathStrategy);
    final current = await RecoveryKeyIdentity.fromMetadata(
      (await harness.repository.readRecoveryMetadata())!,
    );
    expect((await status.read()).requiredBackupIdentity, current);
    expect(current, isNot(old));
    expect((await harness.repository.listTagCatalog()).single.label, '世代標籤');
    await status.recordDriveUploadSuccess(
      jobId: 'old-upload',
      identity: old,
      purpose: VaultBackupPurpose.normal,
    );
    expect((await status.read()).requiredBackupIdentity, current);
    final backup = harness.createTransferIo(session: rotated.session).backup;
    final zip = File('${root.path}/new.zip');
    await backup.writeBackupZip(zip);
    final inspected = await backup.inspectBackup(zip);
    expect(
      await RecoveryKeyIdentity.fromMetadata(inspected.metadata!),
      current,
    );
    final opened = await openZipArchive(zip);
    expect(opened.archive.findFile('tag_styles.json'), isNull);
    expect(opened.archive.findFile('tag_styles.json.enc'), isNotNull);
    await opened.close();
    await status.recordExternalExportSuccess(
      identity: await RecoveryKeyIdentity.fromMetadata(inspected.metadata!),
      purpose: VaultBackupPurpose.normal,
    );
    expect((await status.read()).requiredBackupIdentity, isNull);
  });
}
