import 'package:flutter/widgets.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';

/// 本機尚無可用日記庫：已進入 unlocked，但還沒有 session／復原資訊。
bool isAwaitingVaultSetup(AppSessionState sessionState) {
  return sessionState.status == AppLockStatus.unlocked &&
      sessionState.session == null;
}

/// 首次啟動時解析 App 應立即顯示的語系。
AppLanguage resolveAppLanguage({
  required bool storedLanguageResolved,
  required AppLanguage? storedLanguage,
  required AppSessionState? sessionState,
  required Locale deviceLocale,
  required AppLanguage fallbackLanguage,
}) {
  if (!storedLanguageResolved) {
    return fallbackLanguage;
  }
  if (storedLanguage != null) {
    return storedLanguage;
  }
  if (sessionState != null && isAwaitingVaultSetup(sessionState)) {
    return appLanguageFromDeviceLocale(deviceLocale);
  }
  return fallbackLanguage;
}

/// 僅在空日記庫且尚未看過安裝介紹時顯示 Dialog。
bool shouldShowOnboardingIntro({
  required AppSessionState sessionState,
  required bool hasSeen,
}) {
  return isAwaitingVaultSetup(sessionState) && !hasSeen;
}
