import '../../l10n/l10n.dart';

/// 應用進入背景後，超過此時間再回前景即視為 session 逾時並鎖定。
const Duration kDefaultSessionBackgroundTimeout = Duration(minutes: 3);

/// 可變覆寫供測試注入；產品預設見 [kDefaultSessionBackgroundTimeout]。
Duration defaultSessionTimeout = kDefaultSessionBackgroundTimeout;

/// 將背景逾時長度格式化成設定頁用語（例如 `3 分鐘`）。
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
