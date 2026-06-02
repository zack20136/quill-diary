import '../../../infrastructure/storage/shared/portable_import_result.dart';
import 'settings_copy.dart';

extension PortableImportResultMessages on PortableImportResult {
  bool get isFailure =>
      failureCode != null ||
      failureMessage != null ||
      (importedEntries == 0 && skippedFiles > 0);

  String formatSuccessMessage() {
    if (skippedFiles > 0 && skippedAttachments > 0) {
      return SettingsImportExportCopy.importSuccessWithSkippedFilesAndAttachments(
        importedEntries,
        skippedFiles,
        skippedAttachments,
      );
    }
    if (skippedFiles > 0) {
      return SettingsImportExportCopy.importSuccessWithSkippedFiles(
        importedEntries,
        skippedFiles,
      );
    }
    if (skippedAttachments > 0) {
      return SettingsImportExportCopy.importSuccessWithSkippedAttachments(
        importedEntries,
        skippedAttachments,
      );
    }
    return SettingsImportExportCopy.importSuccess(importedEntries);
  }

  String messageWhenNoEntriesImported() {
    final String fromCode = SettingsImportExportCopy.messageForFailureCode(failureCode);
    if (fromCode.isNotEmpty) {
      return fromCode;
    }
    if (failureMessage != null) {
      return failureMessage!;
    }
    if (skippedFiles > 0) {
      return SettingsImportExportCopy.importAllSkippedMessage;
    }
    return SettingsImportExportCopy.importNoEntriesMessage;
  }
}
