import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../domain/diary/diary_entry.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import 'easy_diary_backup_layout.dart';
import 'easy_diary_photo_resolver.dart';
import 'portable_import_result.dart';
import 'vault_repository.dart';

/// Easy Diary 完整備份（Realm + Photos）匯入。
class EasyDiaryBackupImporter {
  EasyDiaryBackupImporter({
    MethodChannel? realmChannel,
    bool? realmReaderEnabled,
  })  : _realmChannel = realmChannel ?? _defaultRealmChannel,
        _realmReaderEnabled = realmReaderEnabled ?? Platform.isAndroid;

  static const MethodChannel _defaultRealmChannel = MethodChannel(
    'quill_lock_diary/easy_diary_realm',
  );

  static const String kUnsupportedPlatformMessage =
      'Easy Diary 完整備份 zip 目前僅支援在 Android 裝置上匯入；'
      '請改用 Android 版 App。';

  static const String kRealmReadFailureMessage =
      '無法讀取 Easy Diary 備份資料庫（可能版本不相容）。'
      '請在 Easy Diary 重新建立完整備份後再試。';

  final MethodChannel _realmChannel;
  final bool _realmReaderEnabled;

  Future<PortableImportResult?> tryImportFromExtractedRoot({
    required UnlockedVaultSession session,
    required VaultRepository repository,
    required Directory extractedRoot,
  }) async {
    final EasyDiaryBackupLayout? layout = EasyDiaryBackupLayout.tryResolve(extractedRoot);
    if (layout == null) {
      return null;
    }

    if (!_realmReaderEnabled) {
      return const PortableImportResult(
        importedEntries: 0,
        skippedFiles: 0,
        failureMessage: kUnsupportedPlatformMessage,
      );
    }

    final List<_EasyDiaryRealmEntry> realmEntries;
    try {
      realmEntries = await _readRealmEntries(layout.realmSnapshotFile.path);
    } on PlatformException {
      return const PortableImportResult(
        importedEntries: 0,
        skippedFiles: 1,
        failureMessage: kRealmReadFailureMessage,
      );
    } on Object {
      return const PortableImportResult(
        importedEntries: 0,
        skippedFiles: 1,
        failureMessage: kRealmReadFailureMessage,
      );
    }

    final EasyDiaryPhotoIndex photoIndex = EasyDiaryPhotoIndex.scan(layout.photosDirectory);

    var importedEntries = 0;
    var skippedFiles = 0;
    var skippedAttachments = 0;

    for (final _EasyDiaryRealmEntry realmEntry in realmEntries) {
      if (realmEntry.isEncrypt) {
        skippedFiles++;
        continue;
      }

      final _ResolvedEasyDiaryAttachments resolved = await _resolvePhotoAttachments(
        photos: realmEntry.photos,
        photoIndex: photoIndex,
      );
      skippedAttachments += resolved.skippedAttachments;

      final DiaryEntry entry = _mapToDiaryEntry(
        realmEntry,
        importedPhotoKeys: resolved.importedPhotoKeys,
      );
      if ((entry.title?.trim().isEmpty ?? true) && entry.markdownBody.trim().isEmpty) {
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

    if (importedEntries == 0 && skippedFiles == 0 && realmEntries.isEmpty) {
      return const PortableImportResult(
        importedEntries: 0,
        skippedFiles: 1,
        failureMessage: '備份檔內沒有可匯入的日記。',
      );
    }

    return PortableImportResult(
      importedEntries: importedEntries,
      skippedFiles: skippedFiles,
      skippedAttachments: skippedAttachments,
    );
  }

  Future<List<_EasyDiaryRealmEntry>> _readRealmEntries(String realmPath) async {
    final Object? response = await _realmChannel.invokeMethod<Object?>(
      'readDiaryBackup',
      <String, Object>{'realmPath': realmPath},
    );
    if (response is! Map) {
      return const <_EasyDiaryRealmEntry>[];
    }

    final Object? rawEntries = response['entries'];
    if (rawEntries is! List) {
      return const <_EasyDiaryRealmEntry>[];
    }

    final List<_EasyDiaryRealmEntry> parsed = <_EasyDiaryRealmEntry>[];
    for (final Object? rawEntry in rawEntries) {
      if (rawEntry is! Map) {
        continue;
      }
      final _EasyDiaryRealmEntry? entry = _EasyDiaryRealmEntry.tryParse(rawEntry);
      if (entry != null) {
        parsed.add(entry);
      }
    }
    return parsed;
  }

  DiaryEntry _mapToDiaryEntry(
    _EasyDiaryRealmEntry realmEntry, {
    required Set<String> importedPhotoKeys,
  }) {
    final DateTime timestamp = realmEntry.currentTimeMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(realmEntry.currentTimeMillis!)
        : DateTime.now();
    final DateOnly entryDate = _entryDateFromRealm(realmEntry.dateString, timestamp);

    final String title = realmEntry.title?.trim() ?? '';
    final String rawBody = realmEntry.contents ?? '';
    final String body = stripEasyDiaryPhotoPlaceholderLines(rawBody, importedPhotoKeys);

    return DiaryEntry(
      id: generateEntryId(),
      vaultId: 'vlt_LOCAL',
      title: title.isEmpty ? '匯入的日記' : title,
      date: entryDate,
      createdAt: timestamp,
      updatedAt: timestamp,
      markdownBody: body,
    );
  }
}

class _EasyDiaryPhotoRef {
  const _EasyDiaryPhotoRef({
    required this.photoKey,
    this.mimeType,
  });

  final String photoKey;
  final String? mimeType;
}

class _EasyDiaryRealmEntry {
  const _EasyDiaryRealmEntry({
    required this.title,
    required this.contents,
    required this.dateString,
    required this.currentTimeMillis,
    required this.isEncrypt,
    required this.photos,
  });

  final String? title;
  final String? contents;
  final String? dateString;
  final int? currentTimeMillis;
  final bool isEncrypt;
  final List<_EasyDiaryPhotoRef> photos;

  static _EasyDiaryRealmEntry? tryParse(Map<dynamic, dynamic> raw) {
    final List<_EasyDiaryPhotoRef> photos = <_EasyDiaryPhotoRef>[];

    final Object? rawPhotos = raw['photos'];
    if (rawPhotos is List) {
      for (final Object? value in rawPhotos) {
        if (value is! Map) {
          continue;
        }
        final String? photoKey = value['photoKey'] as String?;
        if (photoKey == null || photoKey.trim().isEmpty) {
          continue;
        }
        photos.add(
          _EasyDiaryPhotoRef(
            photoKey: photoKey.trim(),
            mimeType: value['mimeType'] as String?,
          ),
        );
      }
    }

    return _EasyDiaryRealmEntry(
      title: raw['title'] as String?,
      contents: raw['contents'] as String?,
      dateString: raw['dateString'] as String?,
      currentTimeMillis: (raw['currentTimeMillis'] as num?)?.toInt(),
      isEncrypt: raw['isEncrypt'] == true,
      photos: photos,
    );
  }
}

class _ResolvedEasyDiaryAttachments {
  const _ResolvedEasyDiaryAttachments({
    required this.attachments,
    required this.skippedAttachments,
    required this.importedPhotoKeys,
  });

  final List<PendingAttachment> attachments;
  final int skippedAttachments;
  final Set<String> importedPhotoKeys;
}

Future<_ResolvedEasyDiaryAttachments> _resolvePhotoAttachments({
  required List<_EasyDiaryPhotoRef> photos,
  required EasyDiaryPhotoIndex photoIndex,
}) async {
  final List<PendingAttachment> attachments = <PendingAttachment>[];
  final Set<String> seen = <String>{};
  final Set<String> importedPhotoKeys = <String>{};
  var skippedAttachments = 0;

  for (final _EasyDiaryPhotoRef photo in photos) {
    final File? photoFile = photoIndex.resolve(photo.photoKey);
    if (photoFile == null) {
      skippedAttachments++;
      continue;
    }

    final String dedupeKey = photoFile.path.toLowerCase();
    if (!seen.add(dedupeKey)) {
      continue;
    }

    final Uint8List header = await readFileHeader(photoFile);
    final String mimeType = _resolveMimeType(
      header: header,
      realmMimeType: photo.mimeType,
      fileNameHint: photoFile.path,
    );
    if (!mimeType.startsWith('image/')) {
      skippedAttachments++;
      continue;
    }

    final String displayName = preferredImageFilename(
      storedName: p.basename(photoFile.path),
      mimeType: mimeType,
    );

    attachments.add(
      PendingAttachment(
        sourcePath: photoFile.path,
        mimeType: mimeType,
        originalFilename: displayName,
      ),
    );
    importedPhotoKeys.add(photo.photoKey);
  }

  return _ResolvedEasyDiaryAttachments(
    attachments: attachments,
    skippedAttachments: skippedAttachments,
    importedPhotoKeys: importedPhotoKeys,
  );
}

String _resolveMimeType({
  required Uint8List header,
  required String? realmMimeType,
  required String fileNameHint,
}) {
  final String? trimmedRealm = realmMimeType?.trim();
  if (trimmedRealm != null &&
      trimmedRealm.isNotEmpty &&
      trimmedRealm.startsWith('image/')) {
    return trimmedRealm;
  }
  final String sniffed = sniffImageMimeType(header, fileNameHint: fileNameHint);
  if (sniffed.startsWith('image/')) {
    return sniffed;
  }
  return sniffed;
}

DateOnly _entryDateFromRealm(String? dateString, DateTime fallback) {
  final String? trimmed = dateString?.trim();
  if (trimmed != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
    return DateOnly.parse(trimmed);
  }
  return DateOnly.fromDateTime(fallback);
}
