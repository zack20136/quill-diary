import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/storage/portable/backup_archive_inspection.dart';

void main() {
  test('inspectZipEntryNames accepts flat vault backup layout', () {
    final VaultBackupLayout layout = inspectZipEntryNames(<String>[
      'recovery.json',
      'manifest.json.enc',
      'entries/one.md.enc',
      'assets/photo.jpg',
    ]);

    expect(layout.isRestorable, isTrue);
    expect(layout.hasRecovery, isTrue);
    expect(layout.hasManifest, isTrue);
  });

  test(
    'inspectZipEntryNames rejects portable export layout by folder structure',
    () {
      final VaultBackupLayout layout = inspectZipEntryNames(<String>[
        '2026-06-01/My Entry/index.md',
      ]);

      expect(layout.isRestorable, isFalse);
      expect(layout.hasMarkdownPortableLayout, isTrue);
      expect(layout.failureMessage, contains('日記匯出檔'));
    },
  );

  test(
    'inspectZipEntryNames does not treat arbitrary names as portable export',
    () {
      final VaultBackupLayout layout = inspectZipEntryNames(<String>[
        'markdown_2026-05-26_14-03-07/entry.md',
      ]);

      expect(layout.hasMarkdownPortableLayout, isFalse);
    },
  );

  test('inspectZipEntryNames rejects unsafe paths', () {
    final VaultBackupLayout layout = inspectZipEntryNames(<String>[
      'recovery.json',
      '../evil.md.enc',
    ]);

    expect(layout.isRestorable, isFalse);
    expect(layout.failureMessage, contains('不安全路徑'));
  });

  test('inspectZipEntryNames reports missing encrypted payload', () {
    final VaultBackupLayout layout = inspectZipEntryNames(<String>[
      'recovery.json',
      'entries/readme.txt',
    ]);

    expect(layout.isRestorable, isFalse);
    expect(layout.failureMessage, contains('加密資料'));
  });
}
