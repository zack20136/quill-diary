import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';

/// 在 app 暫存目錄建立唯一工作資料夾。
Future<Directory> createWorkingDirectory(
  VaultPathStrategy pathStrategy,
  String prefix,
) async {
  final Directory appRoot = await pathStrategy.appRootDirectory();
  final Directory tempRoot = Directory(p.join(appRoot.path, '_tmp'));
  await tempRoot.create(recursive: true);

  final Directory workingDirectory = Directory(
    p.join(tempRoot.path, '${prefix}_${DateTime.now().microsecondsSinceEpoch}'),
  );
  await workingDirectory.create(recursive: true);
  return workingDirectory;
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
  final candidate = file.existsSync()
      ? file
      : backupFile.existsSync()
      ? backupFile
      : tempFile.existsSync()
      ? tempFile
      : null;
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

bool hasFileReplacementCandidates(File file) =>
    file.existsSync() ||
    File('${file.path}.previous').existsSync() ||
    File('${file.path}.tmp').existsSync();
