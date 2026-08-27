import 'package:flutter_test/flutter_test.dart';

import 'package:quill_diary/infrastructure/drive/drive_upload_job.dart';

void main() {
  group('DriveUploadJobSnapshot', () {
    test('解析進行中上傳並阻擋衝突操作', () {
      final DriveUploadJobSnapshot job = DriveUploadJobSnapshot.fromMap(
        <Object?, Object?>{
          'jobId': '11111111-1111-1111-1111-111111111111',
          'phase': 'UPLOADING',
          'accountId': 'acc',
          'accountEmail': 'a@b.c',
          'stagingPath': '/tmp/a',
          'fileName': 'a.qdbak',
          'sizeBytes': 100,
          'md5': 'abc',
          'remoteFileId': '',
          'confirmedOffset': 40,
          'retryCount': 1,
        },
      );

      expect(job.phase, DriveUploadPhase.uploading);
      expect(job.progressFraction, closeTo(0.4, 0.001));
      expect(job.blocksConflictingDriveActions, isTrue);
      expect(job.needsCompletionHandling, isFalse);
    });

    test('STATUS_PENDING 需要寫入備份狀態', () {
      final DriveUploadJobSnapshot job = DriveUploadJobSnapshot.fromMap(
        <Object?, Object?>{
          'jobId': '11111111-1111-1111-1111-111111111111',
          'phase': 'STATUS_PENDING',
          'accountId': 'acc',
          'accountEmail': 'a@b.c',
          'stagingPath': '/tmp/a',
          'fileName': 'a.qdbak',
          'sizeBytes': 10,
          'md5': 'abc',
          'remoteFileId': 'file-1',
          'confirmedOffset': 10,
          'retryCount': 0,
        },
      );

      expect(job.needsStatusRecording, isTrue);
      expect(job.needsCompletionHandling, isTrue);
    });

    test('PRUNE_PENDING 仍需 finalize', () {
      final DriveUploadJobSnapshot job = DriveUploadJobSnapshot.fromMap(
        <Object?, Object?>{
          'jobId': '11111111-1111-1111-1111-111111111111',
          'phase': 'PRUNE_PENDING',
          'accountId': 'acc',
          'accountEmail': 'a@b.c',
          'stagingPath': '/tmp/a',
          'fileName': 'a.qdbak',
          'sizeBytes': 10,
          'md5': 'abc',
          'remoteFileId': 'file-1',
          'confirmedOffset': 10,
          'retryCount': 0,
        },
      );

      expect(job.needsStatusRecording, isFalse);
      expect(job.needsCompletionHandling, isTrue);
    });

    test('相容舊 CLEANUP_PENDING 與 sha256／attemptCount', () {
      final DriveUploadJobSnapshot job = DriveUploadJobSnapshot.fromMap(
        <Object?, Object?>{
          'jobId': '11111111-1111-1111-1111-111111111111',
          'phase': 'CLEANUP_PENDING',
          'accountId': 'acc',
          'accountEmail': 'a@b.c',
          'stagingPath': '/tmp/a',
          'fileName': 'a.qdbak',
          'sizeBytes': 50,
          'sha256': 'legacy',
          'remoteFileId': 'file-1',
          'confirmedOffset': 25,
          'attemptCount': 2,
        },
      );

      expect(job.phase, DriveUploadPhase.prunePending);
      expect(job.md5, 'legacy');
      expect(job.retryCount, 2);
      expect(job.progressFraction, closeTo(0.5, 0.001));
    });

    test('CANCEL_CLEANUP_PENDING 解析且不走完成收尾', () {
      final DriveUploadJobSnapshot job = DriveUploadJobSnapshot.fromMap(
        <Object?, Object?>{
          'jobId': '11111111-1111-1111-1111-111111111111',
          'phase': 'CANCEL_CLEANUP_PENDING',
          'accountId': 'acc',
          'accountEmail': 'a@b.c',
          'stagingPath': '/tmp/a',
          'fileName': 'a.qdbak',
          'sizeBytes': 10,
          'md5': 'abc',
          'remoteFileId': 'file-1',
          'confirmedOffset': 10,
          'retryCount': 0,
        },
      );

      expect(job.phase, DriveUploadPhase.cancelCleanupPending);
      expect(job.blocksConflictingDriveActions, isTrue);
      expect(job.needsStatusRecording, isFalse);
      expect(job.needsCompletionHandling, isFalse);
    });

    test('未知 phase 拋錯', () {
      expect(
        () => DriveUploadJobSnapshot.fromMap(<Object?, Object?>{
          'jobId': '11111111-1111-1111-1111-111111111111',
          'phase': 'FAILED',
          'accountId': 'acc',
          'accountEmail': 'a@b.c',
          'stagingPath': '/tmp/a',
          'fileName': 'a.qdbak',
          'sizeBytes': 1,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('DriveUploadState', () {
    test('解析 job 與 failure envelope', () {
      final DriveUploadState state = DriveUploadState.fromMap(
        <Object?, Object?>{
          'job': <Object?, Object?>{
            'jobId': '11111111-1111-1111-1111-111111111111',
            'phase': 'STAGED',
            'accountId': 'acc',
            'accountEmail': 'a@b.c',
            'stagingPath': '/tmp/a',
            'fileName': 'a.qdbak',
            'sizeBytes': 1,
            'md5': 'x',
            'remoteFileId': '',
            'confirmedOffset': 0,
            'retryCount': 0,
          },
          'failure': <Object?, Object?>{
            'jobId': '22222222-2222-2222-2222-222222222222',
            'message': '上次失敗',
          },
        },
      );

      expect(state.job?.phase, DriveUploadPhase.staged);
      expect(state.failure?.jobId, '22222222-2222-2222-2222-222222222222');
      expect(state.failure?.message, '上次失敗');
    });
  });
}
