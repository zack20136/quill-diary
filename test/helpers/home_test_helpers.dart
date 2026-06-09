import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import 'fake_vault_repository.dart';

/// 建立已解鎖 session 的 home provider 測試容器。
ProviderContainer buildUnlockedHomeContainer(
  FakeVaultRepository repository, {
  String vaultId = 'vlt_home_provider_test',
}) {
  final UnlockedVaultSession session = UnlockedVaultSession(
    vaultId: vaultId,
    trustedDevice: true,
    recoveryWrapKey: const <int>[1, 2, 3],
  );
  return ProviderContainer(
    overrides: [
      vaultRepositoryProvider.overrideWithValue(repository),
      effectiveAppSessionProvider.overrideWith(
        (Ref ref) async => AppSessionState(
          status: AppLockStatus.unlocked,
          session: session,
        ),
      ),
    ],
  );
}
