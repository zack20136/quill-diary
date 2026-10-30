import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/infrastructure/storage/shared/portable_import_result.dart';
import 'package:quill_diary/l10n/l10n.dart';

extension PortableImportResultPresentation on PortableImportResult {
  String formatSuccessMessage(AppLocalizations l10n) {
    if (skippedFiles > 0 && skippedAttachments > 0) {
      return l10n
          .settingsImportExportImportSuccessWithSkippedFilesAndAttachments(
            importedEntries,
            skippedFiles,
            skippedAttachments,
          );
    }
    if (skippedFiles > 0) {
      return l10n.settingsImportExportImportSuccessWithSkippedFiles(
        importedEntries,
        skippedFiles,
      );
    }
    if (skippedAttachments > 0) {
      return l10n.settingsImportExportImportSuccessWithSkippedAttachments(
        importedEntries,
        skippedAttachments,
      );
    }
    return l10n.settingsImportExportImportSuccess(importedEntries);
  }

  String messageWhenNoEntriesImported(AppLocalizations l10n) {
    final String messageFromFailureCode =
        settingsImportExportMessageForFailureCode(l10n, failureCode);
    if (messageFromFailureCode.isNotEmpty) {
      return messageFromFailureCode;
    }
    if (failureMessage != null) {
      return failureMessage!;
    }
    if (skippedFiles > 0) {
      return l10n.settingsImportExportImportAllSkippedMessage;
    }
    return l10n.settingsImportExportImportNoEntriesMessage;
  }
}
