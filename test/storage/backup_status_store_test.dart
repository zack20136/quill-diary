import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';

void main() {
  late File storageFile;
  late BackupStatusStore store;

  setUp(() async {
    storageFile = File(
      '${Directory.systemTemp.path}\\backup_status_test_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    store = BackupStatusStore(storageFile: storageFile);
  });

  tearDown(() async {
    if (storageFile.existsSync()) {
      await storageFile.delete();
    }
  });

  test('記錄本機備份成功與讀取往返', () async {
    await store.recordLocalBackupSuccess();
    final BackupStatusSnapshot snapshot = await store.read();

    expect(snapshot.lastLocalBackupAt, isNotNull);
    expect(snapshot.hasAnySuccess, isTrue);
  });

  test('記錄 Drive 上傳成功', () async {
    await store.recordDriveUploadSuccess(accountLabel: 'user@example.com');
    final BackupStatusSnapshot snapshot = await store.read();

    expect(snapshot.lastDriveAccountLabel, 'user@example.com');
    expect(snapshot.lastDriveUploadAt, isNotNull);
  });

  test('記錄失敗會保留先前成功時間', () async {
    final DateTime successAt = DateTime(2026, 1, 1, 12);
    await store.recordLocalBackupSuccess(
      at: successAt,
    );
    await store.recordFailure(
      action: BackupStatusAction.localBackup,
      message: 'inspect failed',
      at: DateTime(2026, 1, 2, 12),
    );

    final BackupStatusSnapshot snapshot = await store.read();
    expect(snapshot.lastLocalBackupAt, successAt);
    expect(snapshot.lastFailure?.message, 'inspect failed');
    expect(snapshot.lastFailure?.action, BackupStatusAction.localBackup);
  });

  test('超過 30 天未備份會判定為過久', () async {
    final DateTime staleAt = DateTime.now().subtract(const Duration(days: 31));
    await store.recordLocalBackupSuccess(at: staleAt);

    final BackupStatusSnapshot snapshot = await store.read();
    expect(snapshot.isLocalBackupStale(DateTime.now()), isTrue);
    expect(snapshot.isDriveUploadStale(DateTime.now()), isFalse);
  });

  test('從未備份不視為過久', () async {
    final BackupStatusSnapshot snapshot = await store.read();
    expect(snapshot.isLocalBackupStale(DateTime.now()), isFalse);
    expect(snapshot.isDriveUploadStale(DateTime.now()), isFalse);
  });

  test('本機相關備份會取較新的成功時間', () {
    final DateTime local = DateTime(2026, 1, 1);
    final DateTime external = DateTime(2026, 2, 1);
    final BackupStatusSnapshot snapshot = BackupStatusSnapshot(
      lastLocalBackupAt: local,
      lastExternalExportAt: external,
    );

    expect(snapshot.lastLocalRelatedBackupAt, external);
    expect(
      snapshot.lastLocalRelatedBackupAction,
      BackupStatusAction.externalExport,
    );
  });

  test('Drive 上傳成功但無帳號時不寫入帳號標籤', () async {
    await store.recordDriveUploadSuccess();
    final BackupStatusSnapshot snapshot = await store.read();

    expect(snapshot.lastDriveUploadAt, isNotNull);
    expect(snapshot.lastDriveAccountLabel, isNull);
  });
}
