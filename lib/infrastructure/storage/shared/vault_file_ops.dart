import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
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

/// 以暫存檔寫入後 rename，避免中斷時留下半寫入的目標檔。
Future<void> atomicWriteString(File file, String content) async {
  await file.parent.create(recursive: true);
  final File tempFile = File('${file.path}.tmp');
  await tempFile.writeAsString(content, flush: true);
  if (file.existsSync()) {
    await file.delete();
  }
  await tempFile.rename(file.path);
}

/// 以同目錄 rename 可復原地取代檔案；寫入失敗時保留最後有效版本。
Future<void> replaceFileBytesRecoverably(
  File file,
  Uint8List bytes, {
  void Function()? beforeCommit,
  void Function()? onCommitted,
}) async {
  await file.parent.create(recursive: true);
  await recoverFileReplacement(file);
  final File tempFile = File('${file.path}.tmp');
  final File backupFile = File('${file.path}.previous');
  var movedOriginal = false;
  try {
    await tempFile.writeAsBytes(bytes, flush: true);
    beforeCommit?.call();
    // 檢查取消、發布檔案與更新提交狀態之間不能讓出事件迴圈。
    if (file.existsSync()) {
      file.renameSync(backupFile.path);
      movedOriginal = true;
    }
    tempFile.renameSync(file.path);
    onCommitted?.call();
    if (backupFile.existsSync()) {
      await backupFile.delete();
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
Future<void> recoverFileReplacement(File file) async {
  final File tempFile = File('${file.path}.tmp');
  final File backupFile = File('${file.path}.previous');
  if (!file.existsSync() && backupFile.existsSync()) {
    await backupFile.rename(file.path);
  } else if (file.existsSync() && backupFile.existsSync()) {
    await backupFile.delete();
  }
  if (!file.existsSync() && tempFile.existsSync()) {
    await tempFile.rename(file.path);
  } else if (file.existsSync() && tempFile.existsSync()) {
    await tempFile.delete();
  }
}

/// 刪除檔案（存在時）；忽略刪除失敗。
Future<void> deleteFileIfExists(String path) async {
  final File file = File(path);
  if (!file.existsSync()) {
    return;
  }
  try {
    await file.delete();
  } on Object {
    // 忽略刪除失敗。
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
  await file.parent.create(recursive: true);
  final File tempFile = File('${file.path}.tmp');
  await tempFile.writeAsBytes(bytes, flush: true);
  if (file.existsSync()) {
    await file.delete();
  }
  await tempFile.rename(file.path);
}

/// 呼叫端須已持有 vault 修改序列；只移除聊天擁有的檔案。
Future<void> deleteEntryChatFiles(String entryPath) async {
  final chatPath = VaultPathStrategy.chatFileBesideEntry(entryPath);
  for (final suffix in ['', '.previous', '.tmp']) {
    final file = File('$chatPath$suffix');
    if (file.existsSync()) await file.delete();
  }
}
