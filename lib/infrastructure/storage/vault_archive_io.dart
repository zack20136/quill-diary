import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../domain/attachment/asset_attachment.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../database/index_database.dart';
import '../database/index_database_manager.dart';
import '../markdown/front_matter_codec.dart';
import 'vault_path_strategy.dart';
import 'vault_repository.dart';

class VaultArchiveIo {
  VaultArchiveIo({
    required VaultPathStrategy pathStrategy,
    required VaultRepository repository,
    required FrontMatterCodec frontMatterCodec,
    required IndexDatabaseManager indexDatabaseManager,
  })  : _pathStrategy = pathStrategy,
        _repository = repository,
        _frontMatterCodec = frontMatterCodec,
        _indexDatabaseManager = indexDatabaseManager;

  final VaultPathStrategy _pathStrategy;
  final VaultRepository _repository;
  final FrontMatterCodec _frontMatterCodec;
  final IndexDatabaseManager _indexDatabaseManager;

  Future<File> writeBackupZip(File target) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    await target.parent.create(recursive: true);
    final ZipFileEncoder encoder = ZipFileEncoder();
    encoder.create(target.path);
    await encoder.addDirectory(
      vaultRoot,
      includeDirName: false,
      filter: (FileSystemEntity entity, double progress) {
        final String relative = p.relative(entity.path, from: vaultRoot.path);
        final List<String> segments = p.split(relative);
        if (segments.isNotEmpty && segments.first == 'index') {
          return ZipFileOperation.skip;
        }
        return ZipFileOperation.include;
      },
    );
    await encoder.close();
    return target;
  }

  Future<Directory> exportMarkdown({
    required UnlockedVaultSession session,
    required Directory parentDirectory,
  }) async {
    final List<EntryIndexRecord> entries = await _repository.listEntries();
    final Directory exportRoot = Directory(
      p.join(
        parentDirectory.path,
        'markdown_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    final Directory entryRoot = Directory(p.join(exportRoot.path, 'entries'));
    final Directory assetRoot = Directory(p.join(exportRoot.path, 'assets'));
    await entryRoot.create(recursive: true);
    await assetRoot.create(recursive: true);

    for (final EntryIndexRecord record
        in entries.where((EntryIndexRecord item) => !item.isDeleted)) {
      final DiaryEntry? entry = await _repository.loadEntry(session, record.id);
      if (entry == null) {
        continue;
      }

      final List<AssetAttachment> attachments = await _repository.loadAttachments(
        entry.id,
      );
      final String exportMarkdown = _frontMatterCodec.encode(
        entry,
        attachments: attachments,
      );
      final Directory yearMonthDirectory = Directory(
        p.join(entryRoot.path, entry.date.yearString, entry.date.monthPadded),
      );
      await yearMonthDirectory.create(recursive: true);
      await File(
        p.join(
          yearMonthDirectory.path,
          '${entry.date.value}-${_exportNameSuffix(entry)}.md',
        ),
      ).writeAsString(
        exportMarkdown,
        flush: true,
      );

      for (final AssetAttachment attachment in attachments) {
        final File encryptedFile = File(
          await _pathStrategy.assetAbsolutePath(
            date: entry.date,
            assetId: attachment.id,
            extension: p
                .extension(attachment.safeFilename)
                .replaceFirst('.', ''),
          ),
        );
        if (!encryptedFile.existsSync()) {
          continue;
        }

        final bytes = await _repository.readDecryptedAssetBytes(
          session,
          encryptedFile.path,
        );
        if (bytes == null) {
          continue;
        }
        final Directory assetDirectory = Directory(
          p.join(assetRoot.path, entry.date.yearString, entry.date.monthPadded),
        );
        await assetDirectory.create(recursive: true);
        await File(
          p.join(assetDirectory.path, attachment.safeFilename),
        ).writeAsBytes(bytes, flush: true);
      }
    }

    return exportRoot;
  }

  Future<void> restoreBackupZip(File backupFile) async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    final Directory tempRoot = Directory('${vaultRoot.path}_restore_tmp');
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
    await tempRoot.create(recursive: true);

    final Archive archive = ZipDecoder().decodeBytes(
      await backupFile.readAsBytes(),
      verify: true,
    );
    for (final ArchiveFile archiveFile in archive.files) {
      _ensureSafeArchivePath(archiveFile.name);
      final String outputPath = p.join(tempRoot.path, archiveFile.name);
      if (archiveFile.isFile) {
        final File file = File(outputPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          archiveFile.content as List<int>,
          flush: true,
        );
      } else {
        await Directory(outputPath).create(recursive: true);
      }
    }

    if (vaultRoot.existsSync()) {
      await vaultRoot.delete(recursive: true);
    }
    await vaultRoot.create(recursive: true);
    await for (final FileSystemEntity entity
        in tempRoot.list(recursive: true, followLinks: false)) {
      final String relative = p.relative(entity.path, from: tempRoot.path);
      final String destination = p.join(vaultRoot.path, relative);
      if (entity is Directory) {
        await Directory(destination).create(recursive: true);
      } else if (entity is File) {
        await File(destination).parent.create(recursive: true);
        await entity.copy(destination);
      }
    }

    final Directory strayVaultIndex = Directory(p.join(vaultRoot.path, 'index'));
    if (strayVaultIndex.existsSync()) {
      await strayVaultIndex.delete(recursive: true);
    }

    await tempRoot.delete(recursive: true);
    await _indexDatabaseManager.deleteDatabaseFiles();
    _repository.clearRecoveryMetadataCache();
  }

  void _ensureSafeArchivePath(String relativePath) {
    if (relativePath.contains('..') || p.isAbsolute(relativePath)) {
      throw const FormatException('備份檔包含不安全的路徑。');
    }
  }

  String _exportNameSuffix(DiaryEntry entry) {
    final String title = entry.normalizedTitle ?? '';
    if (title.isNotEmpty) {
      final String sanitized = title
          .replaceAll(RegExp(r'[^\w\u4e00-\u9fff-]+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      if (sanitized.isNotEmpty) {
        return sanitized;
      }
    }
    return entry.id.substring(entry.id.length - 6).toLowerCase();
  }
}
