import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

enum VaultRepairCopyResult { copied, targetExists }

enum VaultRepairDeleteResult { deleted, missing, validationFailed }

/// 修復流程唯一可執行檔案搬移與刪除的入口。
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
