import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/settings/portable_import_result_messages.dart';
import 'package:quill_diary/infrastructure/storage/shared/portable_import_result.dart';

import '../../helpers/test_l10n.dart';

void main() {
  test('messageWhenNoEntriesImported 全部略過時回報通用略過提示', () {
    const PortableImportResult result = PortableImportResult(
      importedEntries: 0,
      skippedFiles: 2,
    );

    expect(result.isFailure(testL10n), isTrue);
    expect(
      result.messageWhenNoEntriesImported(testL10n),
      testL10n.settingsImportExportImportAllSkippedMessage,
    );
  });

  test('messageWhenNoEntriesImported 依 failureCode 回報文案', () {
    const PortableImportResult result = PortableImportResult(
      importedEntries: 0,
      skippedFiles: 0,
      failureCode: PortableImportFailureCode.easyDiaryAllEncrypted,
    );

    expect(result.isFailure(testL10n), isTrue);
    expect(
      result.messageWhenNoEntriesImported(testL10n),
      testL10n.settingsImportExportFailureEasyDiaryAllEncrypted,
    );
  });

  test('formatSuccessMessage 組合略過統計', () {
    const PortableImportResult result = PortableImportResult(
      importedEntries: 3,
      skippedFiles: 1,
      skippedAttachments: 2,
    );

    expect(result.isFailure(testL10n), isFalse);
    expect(
      result.formatSuccessMessage(testL10n),
      testL10n.settingsImportExportImportSuccessWithSkippedFilesAndAttachments(
        3,
        1,
        2,
      ),
    );
  });
}
