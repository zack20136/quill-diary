/// 備份、還原與雲端傳輸的進度階段。
enum BackupTaskPhase {
  creatingBackup,
  copyingBackup,
  uploadingDrive,
  downloadingDrive,
  restoringBackup,
  startingAfterRestore,
}

/// 完整備份 pipeline：建 zip 佔整體進度的比例上限。
const double backupPipelineZipEndFraction = 0.65;

/// 長時間備份任務的進度更新；[fraction] 為 0.0–1.0，`null` 表示尚無法估算。
class BackupTaskProgress {
  const BackupTaskProgress({required this.phase, this.fraction});

  final BackupTaskPhase phase;
  final double? fraction;

  static const BackupTaskProgress startingAfterRestore = BackupTaskProgress(
    phase: BackupTaskPhase.startingAfterRestore,
  );
}

typedef BackupTaskProgressListener = void Function(BackupTaskProgress progress);

const double _progressEmitStep = 0.01;

/// 將子階段 local fraction 映射到整體區間 [start, end]。
BackupTaskProgressListener? remapBackupTaskProgress(
  BackupTaskProgressListener? listener, {
  required double start,
  required double end,
}) {
  if (listener == null) {
    return null;
  }
  return (BackupTaskProgress local) {
    listener(
      BackupTaskProgress(
        phase: local.phase,
        fraction: start + (local.fraction ?? 0) * (end - start),
      ),
    );
  };
}

Stream<List<int>> reportByteStreamProgress(
  Stream<List<int>> stream, {
  required int totalBytes,
  required BackupTaskPhase phase,
  required BackupTaskProgressListener? onProgress,
}) async* {
  if (totalBytes <= 0) {
    onProgress?.call(BackupTaskProgress(phase: phase));
    yield* stream;
    return;
  }

  var completed = 0;
  double? lastEmittedFraction;
  void emitIfNeeded(double fraction) {
    if (onProgress == null) {
      return;
    }
    final double clamped = fraction.clamp(0.0, 1.0);
    if (lastEmittedFraction != null &&
        clamped < 1.0 &&
        clamped - lastEmittedFraction! < _progressEmitStep) {
      return;
    }
    lastEmittedFraction = clamped;
    onProgress(BackupTaskProgress(phase: phase, fraction: clamped));
  }

  await for (final List<int> chunk in stream) {
    completed += chunk.length;
    emitIfNeeded(completed / totalBytes);
    yield chunk;
  }
}
