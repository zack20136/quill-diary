import 'package:quill_diary/l10n/l10n.dart';

const Duration kDefaultSessionBackgroundTimeout = Duration(minutes: 3);
const Duration kSessionForegroundSettleDelay = Duration(milliseconds: 500);

String sessionBackgroundTimeoutLabel(Duration timeout, AppLocalizations l10n) {
  final Duration value = timeout;
  final int minutes = value.inMinutes;
  if (minutes >= 1 && value.inSeconds == minutes * 60) {
    return l10n.sessionBackgroundTimeoutMinutes(minutes);
  }
  return l10n.sessionBackgroundTimeoutSeconds(value.inSeconds);
}

bool hasSessionTimedOut({
  required DateTime lastForegroundExitAt,
  required DateTime now,
  Duration timeout = kDefaultSessionBackgroundTimeout,
}) {
  return now.difference(lastForegroundExitAt) >= timeout;
}
