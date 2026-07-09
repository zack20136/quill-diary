import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/application/session/app_session_controller.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';

import '../../vault/fake_entry_index_vault_repository.dart';

class _HomeTestAppSession extends AppSessionController {
  _HomeTestAppSession(this.initial);

  final AppSessionState initial;

  @override
  AppSessionState build() => initial;
}

class MutableHomeTestAppSession extends AppSessionController {
  MutableHomeTestAppSession(this.initial);

  AppSessionState initial;

  @override
  AppSessionState build() => initial;

  void adopt(AppSessionState next) {
    initial = next;
    state = next;
  }
}

ProviderContainer buildUnlockedHomeContainer(
  FakeEntryIndexVaultRepository repository, {
  String vaultId = 'vlt_home_provider_test',
  List overrides = const [],
}) {
  final UnlockedVaultSession session = UnlockedVaultSession(
    vaultId: vaultId,
    trustedDevice: true,
    recoveryWrapKey: const <int>[1, 2, 3],
  );
  final AppSessionState sessionState = AppSessionState(
    status: AppLockStatus.unlocked,
    session: session,
  );
  return ProviderContainer(
    overrides: [
      vaultRepositoryProvider.overrideWithValue(repository),
      appSessionProvider.overrideWith(() => _HomeTestAppSession(sessionState)),
      effectiveAppSessionProvider.overrideWith(
        (Ref ref) async => ref.watch(appSessionProvider),
      ),
      ...overrides,
    ],
  );
}

ProviderContainer buildMutableHomeContainer({
  required FakeEntryIndexVaultRepository repository,
  required MutableHomeTestAppSession sessionController,
  List overrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      vaultRepositoryProvider.overrideWithValue(repository),
      appSessionProvider.overrideWith(() => sessionController),
      effectiveAppSessionProvider.overrideWith(
        (Ref ref) async => ref.watch(appSessionProvider),
      ),
      ...overrides,
    ],
  );
}
