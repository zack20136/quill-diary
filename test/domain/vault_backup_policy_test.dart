import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/vault_backup_policy.dart';

void main() {
  group('VaultBackupPolicy', () {
    test('backupFileName formats timestamp as backup_YYYY-MM-DD_HH-MM-SS.zip', () {
      expect(
        VaultBackupPolicy.backupFileName(DateTime(2026, 5, 26, 14, 3, 7)),
        'backup_2026-05-26_14-03-07.zip',
      );
    });

    test('hasVaultBackupExtension accepts zip case insensitively', () {
      expect(VaultBackupPolicy.hasVaultBackupExtension('backup.zip'), isTrue);
      expect(VaultBackupPolicy.hasVaultBackupExtension('my_diary_backup.ZIP'), isTrue);
    });

    test('hasVaultBackupExtension rejects non-zip extensions', () {
      expect(VaultBackupPolicy.hasVaultBackupExtension('backup.txt'), isFalse);
      expect(VaultBackupPolicy.hasVaultBackupExtension('backup.jbackup'), isFalse);
    });

    test('markdownPortableFileName formats timestamp as markdown_YYYY-MM-DD_HH-MM-SS.zip', () {
      expect(
        VaultBackupPolicy.markdownPortableFileName(DateTime(2026, 5, 26, 14, 3, 7)),
        'markdown_2026-05-26_14-03-07.zip',
      );
    });

    test('htmlPortableFileName formats timestamp as html_YYYY-MM-DD_HH-MM-SS.html', () {
      expect(
        VaultBackupPolicy.htmlPortableFileName(DateTime(2026, 5, 26, 14, 3, 7)),
        'html_2026-05-26_14-03-07.html',
      );
    });

  });
}
