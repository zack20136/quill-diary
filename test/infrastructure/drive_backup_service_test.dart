import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/infrastructure/drive/drive_backup_service.dart';

void main() {
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
