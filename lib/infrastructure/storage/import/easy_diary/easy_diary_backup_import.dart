import 'dart:io';

import 'package:flutter/services.dart';

import '../../../../config/app_identifiers.dart';
import '../../../../domain/diary/diary_entry.dart';
import '../../../../domain/security/unlocked_vault_session.dart';
import '../../../../domain/shared/value_objects.dart';
import '../../shared/portable_import_result.dart';
import '../../vault_repository.dart';
import 'easy_diary_backup_layout.dart';
import 'easy_diary_photo_resolver.dart';
import 'easy_diary_realm_entry.dart';

/// Easy Diary 完整備份（Realm + Photos）匯入。
class EasyDiaryBackupImporter {
  EasyDiaryBackupImporter({
    MethodChannel? realmChannel,
    bool? realmReaderEnabled,
  }) : _realmChannel = realmChannel ?? _defaultRealmChannel,
       _realmReaderEnabled = realmReaderEnabled ?? Platform.isAndroid;

  static const MethodChannel _defaultRealmChannel = MethodChannel(
    AppIdentifiers.easyDiaryRealmChannel,
  );

  final MethodChannel _realmChannel;
  final bool _realmReaderEnabled;

  Future<PortableImportResult?> tryImportFromExtractedRoot({
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

    if (!_realmReaderEnabled) {
      return const PortableImportResult(
        importedEntries: 0,
        skippedFiles: 0,
        failureCode: PortableImportFailureCode.easyDiaryUnsupportedPlatform,
      );
    }

    final List<EasyDiaryRealmEntry> realmEntries;
    try {
      realmEntries = await _readRealmEntries(layout.realmSnapshotFile.path);
    } on Object {
      return const PortableImportResult(
        importedEntries: 0,
        skippedFiles: 1,
        failureCode: PortableImportFailureCode.easyDiaryRealmReadFailed,
      );
    }

    final EasyDiaryPhotoIndex photoIndex = EasyDiaryPhotoIndex.scan(
      layout.photosDirectory,
    );

    var importedEntries = 0;
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

      await repository.saveEntry(
        session,
        entry,
        pendingAttachments: resolved.attachments,
      );
      importedEntries++;
    }

    if (importedEntries == 0 && realmEntries.isEmpty) {
      return const PortableImportResult(
        importedEntries: 0,
        skippedFiles: 1,
        failureCode: PortableImportFailureCode.easyDiaryEmptyBackup,
      );
    }

    if (importedEntries == 0 && skippedFiles > 0) {
      return PortableImportResult(
        importedEntries: 0,
        skippedFiles: skippedFiles,
        skippedAttachments: skippedAttachments,
        failureCode: PortableImportFailureCode.easyDiaryAllEncrypted,
      );
    }

    return PortableImportResult(
      importedEntries: importedEntries,
      skippedFiles: skippedFiles,
      skippedAttachments: skippedAttachments,
    );
  }

  Future<List<EasyDiaryRealmEntry>> _readRealmEntries(String realmPath) async {
    final Object? response = await _realmChannel.invokeMethod<Object?>(
      'readDiaryBackup',
      <String, Object>{'realmPath': realmPath},
    );
    return parseEasyDiaryRealmEntries(response);
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
