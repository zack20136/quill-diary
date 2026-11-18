import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/shared/media_type_utils.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';

enum VaultRepairCopyResult { copied, targetExists }

enum VaultRepairDeleteResult { deleted, missing, validationFailed }

/// 檢查與修復共用的檔案操作。
class VaultRepairFileOperations {
  const VaultRepairFileOperations();

  Future<List<File>> snapshotFiles(Directory root, String suffix) async {
    if (!root.existsSync()) return const <File>[];
    final List<File> files = <File>[];
    await for (final FileSystemEntity entity in root.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith(suffix)) files.add(entity);
    }
    files.sort(
      (File a, File b) => p.normalize(a.path).compareTo(p.normalize(b.path)),
    );
    return List<File>.unmodifiable(files);
  }

  bool isInsideVaultContent(String absolutePath, String normalizedRoot) {
    final String normalized = p.normalize(absolutePath);
    if (!p.isWithin(normalizedRoot, normalized) &&
        normalized != normalizedRoot) {
      return false;
    }
    final String relative = p
        .relative(normalized, from: normalizedRoot)
        .replaceAll('\\', '/');
    return relative.startsWith('entries/') || relative.startsWith('assets/');
  }

  Future<({List<File> entries, List<File> assets})> snapshotVaultContent(
    Directory vaultRoot,
  ) async => (
    entries: await snapshotFiles(
      Directory(p.join(vaultRoot.path, 'entries')),
      '.md.enc',
    ),
    assets: await snapshotFiles(
      Directory(p.join(vaultRoot.path, 'assets')),
      '.enc',
    ),
  );

  Future<bool> matchesEncryptedFile(
    String path, {
    required UnlockedVaultSession session,
    required CryptoService crypto,
    required String vaultId,
    required String expectedId,
    required String expectedContentType,
    required String expectedPlaintextHash,
    required bool validateAttachmentContent,
  }) async {
    final ParsedEncryptedDocument parsed = crypto.parseFileBytes(
      await File(path).readAsBytes(),
    );
    if (parsed.header.fileId != expectedId ||
        parsed.header.vaultId != vaultId ||
        parsed.header.contentType != expectedContentType) {
      return false;
    }
    final List<int> plaintext = await crypto.decryptBytes(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: vaultDecryptionContext(session),
    );
    if (validateAttachmentContent &&
        !attachmentContentMatchesMimeType(plaintext, expectedContentType)) {
      return false;
    }
    return await hashVaultBytes(plaintext) == expectedPlaintextHash;
  }

  Future<VaultRepairCopyResult> copyAtomicallyIfAbsent({
    required String sourcePath,
    required String targetPath,
    required Future<bool> Function(String copiedPath) validate,
  }) async {
    final File target = File(targetPath);
    if (target.existsSync()) return VaultRepairCopyResult.targetExists;
    await target.parent.create(recursive: true);
    final String token =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    final File temporary = File('$targetPath.repair_$token.tmp');
    final List<int> reservationMarker = 'repair-reservation-$token'.codeUnits;
    var ownsReservation = false;
    try {
      await File(sourcePath).copy(temporary.path);
      if (!await validate(temporary.path)) {
        throw StateError('修復暫存檔驗證失敗。');
      }
      try {
        await target.create(exclusive: true);
        ownsReservation = true;
        await target.writeAsBytes(reservationMarker, flush: true);
      } on FileSystemException {
        if (target.existsSync()) return VaultRepairCopyResult.targetExists;
        rethrow;
      }
      await temporary.rename(targetPath);
      ownsReservation = false;
      return VaultRepairCopyResult.copied;
    } finally {
      if (ownsReservation && target.existsSync()) {
        try {
          if (_sameBytes(await target.readAsBytes(), reservationMarker)) {
            await target.delete();
          }
        } on FileSystemException {
          // 無法確認仍是本次保留檔時維持原狀，避免誤刪外部寫入。
        }
      }
      if (temporary.existsSync()) await temporary.delete();
    }
  }

  Future<VaultRepairDeleteResult> deleteIfValid({
    required String path,
    required Future<bool> Function(String currentPath) validate,
  }) async {
    final File file = File(path);
    if (!file.existsSync()) return VaultRepairDeleteResult.missing;
    try {
      if (!await validate(path)) {
        return VaultRepairDeleteResult.validationFailed;
      }
    } on Object {
      return VaultRepairDeleteResult.validationFailed;
    }
    if (!file.existsSync()) return VaultRepairDeleteResult.missing;
    await file.delete();
    return VaultRepairDeleteResult.deleted;
  }
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
