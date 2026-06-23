enum UnlockRequestSource { manual, lifecycleResume }

enum UnlockOutcome { success, failed }

/// 最近一次 trusted unlock 的結果，供 App 層路由決策後須 consume。
class CompletedUnlockSnapshot {
  const CompletedUnlockSnapshot({
    required this.source,
    required this.outcome,
    this.recoverable = false,
  });

  final UnlockRequestSource source;
  final UnlockOutcome outcome;
  final bool recoverable;
}
