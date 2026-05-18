Duration defaultSessionTimeout = const Duration(minutes: 5);

bool hasSessionTimedOut({
  required DateTime lastForegroundExitAt,
  required DateTime now,
  Duration timeout = const Duration(minutes: 5),
}) {
  return now.difference(lastForegroundExitAt) >= timeout;
}

