import 'dart:io';

import 'package:flutter/services.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/import/easy_diary/easy_diary_backup_layout.dart';
import 'package:quill_diary/infrastructure/storage/import/easy_diary/easy_diary_photo_resolver.dart';
import 'package:quill_diary/infrastructure/storage/import/easy_diary/easy_diary_realm_entry.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_import_preview.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_io_types.dart';
import 'package:quill_diary/infrastructure/storage/shared/portable_import_result.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/shared/app_identifiers.dart';

/// Easy Diary 完整備份（Realm + Photos）匯入。
class EasyDiaryBackupImporter {
  EasyDiaryBackupImporter({MethodChannel? realmChannel})
    : _realmChannel = realmChannel ?? _defaultRealmChannel;

  static const MethodChannel _defaultRealmChannel = MethodChannel(
    AppIdentifiers.easyDiaryRealmChannel,
  );

  final MethodChannel _realmChannel;

  /// 解析 Easy Diary 備份（不寫入）。非 Easy Diary 佈局時回傳 null。
  Future<AnalyzedPortableImport?> tryAnalyzeFromExtractedRoot({
    required UnlockedVaultSession session,
    required VaultRepository repository,
    required Directory extractedRoot,
  }) async {
    final EasyDiaryBackupLayout? layout = EasyDiaryBackupLayout.tryResolve(
      extractedRoot,
    );
    if (layout == null) {
      return null;
    }

    final List<EasyDiaryRealmEntry> realmEntries;
    try {
      realmEntries = await _readRealmEntries(layout.realmSnapshotFile.path);
    } on Object {
      return AnalyzedPortableImport(
        parsedEntries: const <ParsedImportEntry>[],
        preview: const PortableImportPreview(
          entries: <PortableImportPreviewEntry>[],
          skippedFiles: 1,
          skippedAttachments: 0,
        ),
        failureCode: PortableImportFailureCode.easyDiaryRealmReadFailed,
      );
    }

    final EasyDiaryPhotoIndex photoIndex = EasyDiaryPhotoIndex.scan(
      layout.photosDirectory,
    );

    final List<ParsedImportEntry> parsedEntries = <ParsedImportEntry>[];
    var skippedFiles = 0;
    var skippedAttachments = 0;

    for (final EasyDiaryRealmEntry realmEntry in realmEntries) {
      if (realmEntry.isEncrypt) {
        skippedFiles++;
        continue;
      }

      final ResolvedEasyDiaryAttachments resolved =
          await resolveEasyDiaryPhotoAttachments(
            photos: realmEntry.photos,
            photoIndex: photoIndex,
          );
      skippedAttachments += resolved.skippedAttachments;

      final DiaryEntry entry = _mapToDiaryEntry(
        session: session,
        realmEntry: realmEntry,
        importedPhotoKeys: resolved.importedPhotoKeys,
      );
      if ((entry.title?.trim().isEmpty ?? true) &&
          entry.markdownBody.trim().isEmpty) {
        skippedFiles++;
        continue;
      }

      parsedEntries.add(
        ParsedImportEntry(
          entry: entry,
          attachments: resolved.attachments,
          skippedAttachments: resolved.skippedAttachments,
        ),
      );
    }

    if (parsedEntries.isEmpty && realmEntries.isEmpty) {
      return AnalyzedPortableImport(
        parsedEntries: const <ParsedImportEntry>[],
        preview: PortableImportPreview(
          entries: const <PortableImportPreviewEntry>[],
          skippedFiles: skippedFiles == 0 ? 1 : skippedFiles,
          skippedAttachments: skippedAttachments,
        ),
        failureCode: PortableImportFailureCode.easyDiaryEmptyBackup,
      );
    }

    if (parsedEntries.isEmpty && skippedFiles > 0) {
      return AnalyzedPortableImport(
        parsedEntries: const <ParsedImportEntry>[],
        preview: PortableImportPreview(
          entries: const <PortableImportPreviewEntry>[],
          skippedFiles: skippedFiles,
          skippedAttachments: skippedAttachments,
        ),
        failureCode: PortableImportFailureCode.easyDiaryAllEncrypted,
      );
    }

    final Set<String> existingKeys = await _existingDuplicateKeys(
      session: session,
      repository: repository,
    );
    final List<PortableImportPreviewEntry> previewEntries =
        <PortableImportPreviewEntry>[];
    for (var index = 0; index < parsedEntries.length; index++) {
      final ParsedImportEntry parsed = parsedEntries[index];
      final String displayTitle = portableImportDisplayTitle(parsed.entry);
      previewEntries.add(
        PortableImportPreviewEntry(
          previewIndex: index,
          date: parsed.entry.date,
          title: parsed.entry.normalizedTitle,
          displayTitle: displayTitle,
          likelyDuplicate: existingKeys.contains(
            portableImportDuplicateKey(parsed.entry),
          ),
          attachmentCount: parsed.attachments.length,
          skippedAttachments: parsed.skippedAttachments,
        ),
      );
    }

    return AnalyzedPortableImport(
      parsedEntries: parsedEntries,
      preview: PortableImportPreview(
        entries: previewEntries,
        skippedFiles: skippedFiles,
        skippedAttachments: skippedAttachments,
      ),
    );
  }

  Future<PortableImportResult?> tryImportFromExtractedRoot({
    required UnlockedVaultSession session,
    required VaultRepository repository,
    required Directory extractedRoot,
  }) async {
    final AnalyzedPortableImport? analyzed = await tryAnalyzeFromExtractedRoot(
      session: session,
      repository: repository,
      extractedRoot: extractedRoot,
    );
    if (analyzed == null) {
      return null;
    }
    if (analyzed.failureCode != null && !analyzed.hasImportableEntries) {
      return PortableImportResult(
        importedEntries: 0,
        skippedFiles: analyzed.preview.skippedFiles,
        skippedAttachments: analyzed.preview.skippedAttachments,
        failureCode: analyzed.failureCode,
      );
    }

    var importedEntries = 0;
    for (final ParsedImportEntry parsed in analyzed.parsedEntries) {
      await repository.saveEntry(
        session,
        parsed.entry,
        pendingAttachments: parsed.attachments,
      );
      importedEntries++;
    }

    return PortableImportResult(
      importedEntries: importedEntries,
      skippedFiles: analyzed.preview.skippedFiles,
      skippedAttachments: analyzed.preview.skippedAttachments,
    );
  }

  Future<List<EasyDiaryRealmEntry>> _readRealmEntries(String realmPath) async {
    final Object? response = await _realmChannel.invokeMethod<Object?>(
      'readDiaryBackup',
      <String, Object>{'realmPath': realmPath},
    );
    return parseEasyDiaryRealmEntries(response);
  }

  Future<Set<String>> _existingDuplicateKeys({
    required UnlockedVaultSession session,
    required VaultRepository repository,
  }) async {
    final List<DiaryEntrySummary> records = await repository.listEntries();
    final Set<String> keys = <String>{};
    for (final DiaryEntrySummary record in records) {
      final String titleKey;
      final String? normalized = record.title?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        titleKey = normalized;
      } else {
        final DiaryEntry? entry = await repository.loadEntry(
          session,
          record.id,
        );
        titleKey = entry == null ? '' : portableImportDisplayTitle(entry);
      }
      keys.add('${record.date.value}\u0000$titleKey');
    }
    return keys;
  }

  DiaryEntry _mapToDiaryEntry({
    required UnlockedVaultSession session,
    required EasyDiaryRealmEntry realmEntry,
    required Set<String> importedPhotoKeys,
  }) {
    final DateTime timestamp = realmEntry.currentTimeMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(realmEntry.currentTimeMillis!)
        : DateTime.now();
    final DateOnly entryDate = entryDateFromEasyDiaryRealm(
      realmEntry.dateString,
      timestamp,
    );

    final String title = realmEntry.title?.trim() ?? '';
    final String rawBody = realmEntry.contents ?? '';
    final String body = stripEasyDiaryPhotoPlaceholderLines(
      rawBody,
      importedPhotoKeys,
    );

    return DiaryEntry(
      id: generateEntryId(),
      vaultId: session.vaultId,
      title: title.isEmpty ? '匯入的日記' : title,
      date: entryDate,
      createdAt: timestamp,
      updatedAt: timestamp,
      markdownBody: body,
    );
  }
}
