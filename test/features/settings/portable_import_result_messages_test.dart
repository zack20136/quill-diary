import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/features/settings/portable_import_result_messages.dart';
import 'package:quill_lock_diary/features/settings/settings_copy.dart';
import 'package:quill_lock_diary/infrastructure/storage/shared/portable_import_result.dart';

void main() {
  test('messageWhenNoEntriesImported 全部略過時回報通用略過提示', () {
    const PortableImportResult result = PortableImportResult(
      importedEntries: 0,
      skippedFiles: 2,
    );

    expect(result.isFailure, isTrue);
    expect(
      result.messageWhenNoEntriesImported(),
      SettingsImportExportCopy.importAllSkippedMessage,
    );
  });

  test('messageWhenNoEntriesImported 依 failureCode 回報文案', () {
    const PortableImportResult result = PortableImportResult(
      importedEntries: 0,
      skippedFiles: 0,
      failureCode: PortableImportFailureCode.easyDiaryAllEncrypted,
    );

    expect(result.isFailure, isTrue);
    expect(
      result.messageWhenNoEntriesImported(),
      SettingsImportExportCopy.importFailureEasyDiaryAllEncrypted,
    );
  });

  test('formatSuccessMessage 組合略過統計', () {
    const PortableImportResult result = PortableImportResult(
      importedEntries: 3,
      skippedFiles: 1,
      skippedAttachments: 2,
    );

    expect(result.isFailure, isFalse);
    expect(
      result.formatSuccessMessage(),
      SettingsImportExportCopy.importSuccessWithSkippedFilesAndAttachments(3, 1, 2),
    );
  });
}
