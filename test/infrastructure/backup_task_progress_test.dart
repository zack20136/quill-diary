import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';

void main() {
  test('reportByteStreamProgress with unknown size notifies once', () async {
    final List<BackupTaskProgress> updates = <BackupTaskProgress>[];
    await for (final _ in reportByteStreamProgress(
      Stream<List<int>>.fromIterable(<List<int>>[
        <int>[1, 2, 3],
        <int>[4, 5],
      ]),
      totalBytes: 0,
      phase: BackupTaskPhase.downloadingDrive,
      onProgress: updates.add,
    )) {}

    expect(updates, hasLength(1));
    expect(updates.single.phase, BackupTaskPhase.downloadingDrive);
    expect(updates.single.fraction, isNull);
  });

  test('reportByteStreamProgress throttles updates and finishes at 1.0', () async {
    final List<BackupTaskProgress> updates = <BackupTaskProgress>[];
    const int chunkCount = 200;
    final List<List<int>> chunks = List<List<int>>.generate(
      chunkCount,
      (int index) => <int>[index % 251],
    );

    await for (final _ in reportByteStreamProgress(
      Stream<List<int>>.fromIterable(chunks),
      totalBytes: chunkCount,
      phase: BackupTaskPhase.uploadingDrive,
      onProgress: updates.add,
    )) {}

    expect(updates.length, lessThan(chunkCount));
    expect(updates.last.fraction, 1.0);
  });

  test('remapBackupTaskProgress maps local fraction into overall range', () {
    final List<BackupTaskProgress> updates = <BackupTaskProgress>[];
    final BackupTaskProgressListener listener = remapBackupTaskProgress(
      updates.add,
      start: backupPipelineZipEndFraction,
      end: 1,
    )!;

    listener(
      const BackupTaskProgress(
        phase: BackupTaskPhase.uploadingDrive,
        fraction: 0,
      ),
    );
    listener(
      const BackupTaskProgress(
        phase: BackupTaskPhase.uploadingDrive,
        fraction: 1,
      ),
    );

    expect(updates.first.fraction, closeTo(backupPipelineZipEndFraction, 0.0001));
    expect(updates.last.fraction, closeTo(1, 0.0001));
  });
}
