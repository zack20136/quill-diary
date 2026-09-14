import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/onboarding/onboarding_intro.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';

void main() {
  test('只有空日記庫且版本較舊時才顯示介紹', () {
    const AppSessionState emptyVault = AppSessionState(
      status: AppLockStatus.unlocked,
    );
    const AppSessionState unlocked = AppSessionState(
      status: AppLockStatus.unlocked,
      session: UnlockedVaultSession(
        vaultId: 'vlt_onboarding',
        trustedDevice: true,
        recoveryWrapKey: <int>[1],
      ),
    );

    expect(isAwaitingVaultSetup(emptyVault), isTrue);
    expect(
      shouldShowOnboardingIntro(sessionState: emptyVault, storedVersion: 0),
      isTrue,
    );
    expect(
      shouldShowOnboardingIntro(
        sessionState: emptyVault,
        storedVersion: onboardingIntroCurrentVersion,
      ),
      isFalse,
    );
    expect(
      shouldShowOnboardingIntro(sessionState: unlocked, storedVersion: 0),
      isFalse,
    );
    expect(
      shouldShowOnboardingIntro(
        sessionState: const AppSessionState(status: AppLockStatus.locked),
        storedVersion: 0,
      ),
      isFalse,
    );
    expect(
      shouldShowOnboardingIntro(
        sessionState: const AppSessionState(
          status: AppLockStatus.recoveryRequired,
        ),
        storedVersion: 0,
      ),
      isFalse,
    );
  });

  group('resolveAppLanguage', () {
    const AppSessionState emptyVault = AppSessionState(
      status: AppLockStatus.unlocked,
    );
    const AppSessionState unlocked = AppSessionState(
      status: AppLockStatus.unlocked,
      session: UnlockedVaultSession(
        vaultId: 'vlt_locale',
        trustedDevice: true,
        recoveryWrapKey: <int>[1],
      ),
    );

    test('未寫入語系且空庫時會依英文裝置顯示英文', () {
      expect(
        resolveAppLanguage(
          storedLanguageResolved: true,
          storedLanguage: null,
          sessionState: emptyVault,
          deviceLocale: const Locale('en', 'US'),
          fallbackLanguage: AppLanguage.zh,
        ),
        AppLanguage.en,
      );
    });

    test('未寫入語系但已有日記庫時維持繁中', () {
      expect(
        resolveAppLanguage(
          storedLanguageResolved: true,
          storedLanguage: null,
          sessionState: unlocked,
          deviceLocale: const Locale('en', 'US'),
          fallbackLanguage: AppLanguage.zh,
        ),
        AppLanguage.zh,
      );
    });

    test('已儲存語系時優先於裝置語系', () {
      expect(
        resolveAppLanguage(
          storedLanguageResolved: true,
          storedLanguage: AppLanguage.zh,
          sessionState: emptyVault,
          deviceLocale: const Locale('en', 'US'),
          fallbackLanguage: AppLanguage.en,
        ),
        AppLanguage.zh,
      );
    });

    test('儲存語系尚未解析時不提前採用裝置語系', () {
      expect(
        resolveAppLanguage(
          storedLanguageResolved: false,
          storedLanguage: null,
          sessionState: emptyVault,
          deviceLocale: const Locale('en', 'US'),
          fallbackLanguage: AppLanguage.zh,
        ),
        AppLanguage.zh,
      );
    });

    test('session 尚未解析時不提前採用裝置語系', () {
      expect(
        resolveAppLanguage(
          storedLanguageResolved: true,
          storedLanguage: null,
          sessionState: null,
          deviceLocale: const Locale('en', 'US'),
          fallbackLanguage: AppLanguage.zh,
        ),
        AppLanguage.zh,
      );
    });
  });
}
