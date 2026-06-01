import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/infrastructure/drive/drive_backup_service.dart';

void main() {
  group('isVisibleDriveBackupFileName', () {
    test('accepts visible backup names', () {
      expect(isVisibleDriveBackupFileName('backup_2026-05-26.jbackup'), isTrue);
    });

    test('rejects names that download step would block', () {
      expect(isVisibleDriveBackupFileName(null), isFalse);
      expect(isVisibleDriveBackupFileName('backup.jbackup.tmp'), isFalse);
      expect(isVisibleDriveBackupFileName('../backup.jbackup'), isFalse);
      expect(isVisibleDriveBackupFileName(r'C:\temp\backup.jbackup'), isFalse);
    });
  });

  group('sanitizeDriveBackupFileName', () {
    test('accepts safe jbackup file names', () {
      expect(
        sanitizeDriveBackupFileName('backup_2026-05-26.jbackup'),
        'backup_2026-05-26.jbackup',
      );
    });

    test('rejects path traversal and absolute-looking names', () {
      expect(
        () => sanitizeDriveBackupFileName('../backup.jbackup'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => sanitizeDriveBackupFileName(r'C:\temp\backup.jbackup'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => sanitizeDriveBackupFileName('/tmp/backup.jbackup'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects non backup extensions', () {
      expect(
        () => sanitizeDriveBackupFileName('backup.zip'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
