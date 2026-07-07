enum UnlockRequestSource { manual, lifecycleResume }

enum UnlockOutcome { success, failed }

class SessionUnlockResultEvent {
  const SessionUnlockResultEvent({
    required this.source,
    required this.outcome,
    this.recoverable = false,
  });

  final UnlockRequestSource source;
  final UnlockOutcome outcome;
  final bool recoverable;
}
