import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';

/// 帶進度的複製會等待寫入端，以限制緩衝區。
Future<void> copyFileToPath(
  File source,
  String destinationPath, {
  BackupTaskProgressListener? onProgress,
  BackupTaskPhase phase = BackupTaskPhase.copyingBackup,
}) async {
  final File destination = File(destinationPath);
  await destination.parent.create(recursive: true);
  if (onProgress == null) {
    await source.copy(destinationPath);
    return;
  }

  final int totalBytes = await source.length();
  onProgress(BackupTaskProgress(phase: phase));
  await writeByteStreamToFile(
    reportByteStreamProgress(
      source.openRead(),
      totalBytes: totalBytes,
      phase: phase,
      onProgress: onProgress,
    ),
    destination,
  );
}

Future<void> writeByteStreamToFile(
  Stream<List<int>> source,
  File destination,
) async {
  final IOSink sink = destination.openWrite();
  // 寫入錯誤會另外傳給 done，實際錯誤由下方等待的操作處理。
  sink.done.ignore();
  try {
    await sink.addStream(source);
    await sink.flush();
  } on Object {
    try {
      await sink.close();
    } on Object {
      // 保留首次複製或寫入失敗。
    }
    rethrow;
  }
  await sink.close();
}

/// 在 app 暫存目錄建立唯一工作資料夾。
Future<Directory> createWorkingDirectory(
  VaultPathStrategy pathStrategy,
  String prefix,
) async {
  final Directory tempRoot = await pathStrategy.transferWorkDirectory();
  await tempRoot.create(recursive: true);
  return tempRoot.createTemp('${prefix}_');
}

/// 修復時清除前次程序的暫存。整個現行程序目錄保留，內部可能有其他工作。
Future<void> cleanupAbandonedLocalArtifacts(VaultPathStrategy paths) async {
  for (final active in [
    await paths.editorDraftPreviewWorkDirectory(),
    await paths.transferWorkDirectory(),
  ]) {
    final Directory root = active.parent;
    if (!root.existsSync()) continue;
    try {
      await for (final artifact in root.list(followLinks: false)) {
        if (p.equals(artifact.path, active.path)) continue;
        try {
          await artifact.delete(recursive: artifact is Directory);
        } on FileSystemException {
          // 保留無法清除的項目，讓其他暫存仍可清理。
        }
      }
    } on FileSystemException {
      // 掃描失敗時留到下次修復再試。
    }
  }
  final backups = await paths.localBackupsDirectory();
  if (!backups.existsSync()) return;
  try {
    await for (final file in backups.list(followLinks: false)) {
      if (file is File &&
          p.extension(file.path) == '.partial' &&
          isPrefixedId(p.basenameWithoutExtension(file.path), 'bkp')) {
        await deleteFileIfExists(file.path);
      }
    }
  } on FileSystemException {
    // 掃描失敗時保留正式備份。
  }
}

/// 以可復原替換寫入文字檔，避免中斷時失去最後有效版本。
Future<void> atomicWriteString(File file, String content) async {
  await replaceFileBytesRecoverably(
    file,
    Uint8List.fromList(utf8.encode(content)),
  );
}

/// 以同目錄 rename 可復原地取代檔案；寫入失敗時保留最後有效版本。
Future<void> replaceFileBytesRecoverably(
  File file,
  Uint8List bytes, {
  void Function()? beforeCommit,
  void Function()? onCommitted,
  Future<void> Function(File temporary)? validateTemporary,
}) async {
  await file.parent.create(recursive: true);
  await recoverFileReplacement(file);
  final File tempFile = File('${file.path}.tmp');
  final File backupFile = File('${file.path}.previous');
  var movedOriginal = false;
  try {
    await tempFile.writeAsBytes(bytes, flush: true);
    await validateTemporary?.call(tempFile);
    beforeCommit?.call();
    // 檢查取消、發布檔案與更新提交狀態之間不能讓出事件迴圈。
    if (file.existsSync()) {
      file.renameSync(backupFile.path);
      movedOriginal = true;
    }
    tempFile.renameSync(file.path);
    onCommitted?.call();
    if (backupFile.existsSync()) {
      try {
        await backupFile.delete();
      } on FileSystemException {
        // 主檔已提交；舊副本下次再清理，不把成功寫入回報成失敗。
      }
    }
  } on Object catch (error, stackTrace) {
    if (!file.existsSync() && movedOriginal && backupFile.existsSync()) {
      await backupFile.rename(file.path);
    }
    if (tempFile.existsSync()) {
      await tempFile.delete();
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

/// 修復上次可復原替換在程序中止時留下的同目錄檔案。
///
/// 主檔優先，其次為舊副本、暫存檔；選定後先驗證，再搬移或清理。
/// 驗證失敗時保留所有檔案，不跳過損毀候選而採用另一份內容。
Future<void> recoverFileReplacement(
  File file, {
  Future<void> Function(File candidate)? validate,
}) async {
  final File tempFile = File('${file.path}.tmp');
  final File backupFile = File('${file.path}.previous');
  final candidate = fileReplacementCandidate(file);
  if (candidate != null) await validate?.call(candidate);
  if (!file.existsSync() && backupFile.existsSync()) {
    await backupFile.rename(file.path);
  } else if (file.existsSync() && backupFile.existsSync()) {
    await deleteFileIfExists(backupFile.path);
  }
  if (!file.existsSync() && tempFile.existsSync()) {
    await tempFile.rename(file.path);
  } else if (file.existsSync() && tempFile.existsSync()) {
    await deleteFileIfExists(tempFile.path);
  }
}

/// 驗證加密檔身分並解碼 JSON；個別功能仍須驗證自身的資料結構。
Future<Map<String, dynamic>> readVaultJson(
  File file,
  CryptoService crypto,
  UnlockedVaultSession session, {
  required String identity,
}) async {
  final parsed = crypto.parseFileBytes(await file.readAsBytes());
  if (parsed.header.vaultId != session.vaultId ||
      parsed.header.fileId != identity ||
      parsed.header.contentType != 'application/json') {
    throw const FormatException('加密 JSON 檔案身分不符');
  }
  final bytes = await crypto.decryptBytes(
    headerBytes: parsed.headerBytes,
    ciphertextBytes: parsed.ciphertextBytes,
    context: vaultDecryptionContext(session),
  );
  return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
}

/// 加密內容或 JSON 讀不出來。檔案系統與其他錯誤應原樣丟出。
bool isUnreadableContentError(Object error) =>
    error is FormatException ||
    error is TypeError ||
    error is ArgumentError ||
    error is SecretBoxAuthenticationError;

/// 刪除檔案（存在時）；忽略刪除失敗。
Future<void> deleteFileIfExists(String path) async {
  final File file = File(path);
  if (!file.existsSync()) {
    return;
  }
  try {
    await file.delete();
  } on Object {
    // 清理失敗不得覆蓋呼叫端的操作結果。
  }
}

DecryptionContext vaultDecryptionContext(UnlockedVaultSession session) {
  return DecryptionContext(
    vaultId: session.vaultId,
    trustedDevice: session.trustedDevice,
    recoveryWrapKey: session.recoveryWrapKey,
    deviceSlotId: session.deviceSlotId,
  );
}

/// 加密一段內容並可復原地取代目標檔。呼叫端負責 metadata、身分與寫入後驗證。
Future<void> writeEncryptedVaultJson({
  required File file,
  required CryptoService crypto,
  required UnlockedVaultSession session,
  required RecoveryMetadata metadata,
  required String documentId,
  required List<int> plaintextBytes,
  DateTime? createdAt,
  DateTime? updatedAt,
  String contentType = 'application/json',
  bool Function()? commitWhen,
  Future<void> Function(File temporary)? validateTemporary,
  void Function()? beforeCommit,
  void Function()? onCommitted,
}) async {
  final DateTime now = DateTime.now();
  final EncryptionResult encrypted = await crypto.encryptBytes(
    documentId: documentId,
    vaultId: metadata.vaultId,
    plaintextBytes: plaintextBytes,
    contentType: contentType,
    recoveryWrapKey: requireRecoveryWrapKey(session),
    recoverySlotKdf: metadata.kdf,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
  // 加密期間工作可能已失效；這時留下原檔，不把放棄寫入當成錯誤。
  if (commitWhen != null && !commitWhen()) return;
  await replaceFileBytesRecoverably(
    file,
    encrypted.toFileBytes(),
    validateTemporary: validateTemporary,
    beforeCommit: beforeCommit,
    onCommitted: onCommitted,
  );
}

List<int> requireRecoveryWrapKey(UnlockedVaultSession session) {
  final List<int>? recoveryWrapKey = session.recoveryWrapKey;
  if (recoveryWrapKey == null) {
    throw StateError('目前 session 沒有可用的 Recovery wrapping key。');
  }
  return recoveryWrapKey;
}

Future<String> hashVaultText(String value) async {
  return hashVaultBytes(utf8.encode(value));
}

Future<String> hashVaultBytes(List<int> bytes) async {
  final Hash hash = await Sha256().hash(bytes);
  return hash.bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

Future<void> atomicWriteBytes(File file, Uint8List bytes) async {
  await replaceFileBytesRecoverably(file, bytes);
}

/// 呼叫端須已持有日記庫修改序列；只移除聊天擁有的檔案。
Future<void> deleteEntryChatFiles(String entryPath) async {
  final chatPath = VaultPathStrategy.chatFileBesideEntry(entryPath);
  for (final suffix in ['', '.previous', '.tmp']) {
    final file = File('$chatPath$suffix');
    if (file.existsSync()) await file.delete();
  }
}

File? fileReplacementCandidate(File file) {
  if (file.existsSync()) return file;
  for (final suffix in ['.previous', '.tmp']) {
    final candidate = File('${file.path}$suffix');
    if (candidate.existsSync()) return candidate;
  }
  return null;
}

bool hasFileReplacementCandidates(File file) =>
    fileReplacementCandidate(file) != null;
