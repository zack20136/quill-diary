import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/shared/value_objects.dart';
import '../../infrastructure/storage/vault_repository.dart';
import '../../l10n/l10n.dart';
import '../../shared/presentation/app_feedback.dart';
import '../../shared/providers/core_providers.dart';
import '../../shared/utils/user_facing_error.dart';
import '../session/state/app_session_state.dart';
import 'providers/home_providers.dart';
import 'state/home_state.dart';

Future<void> togglePinSelectedHomeEntries(
  BuildContext context,
  WidgetRef ref,
  AppSessionState sessionState,
  Set<EntryId> selectedIds,
  Set<EntryId> pinnedIds,
) async {
  if (sessionState.session == null || selectedIds.isEmpty) {
    return;
  }

  final bool allSelectedPinned = homeSelectionAllPinned(selectedIds, pinnedIds);
  final bool pin = !allSelectedPinned;
  final int count = selectedIds.length;
  final VaultRepository repository = ref.read(vaultRepositoryProvider);
  try {
    await repository.setEntriesPinned(selectedIds, pinned: pin);
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    showAppFeedbackSnackBar(
      context,
      userFacingErrorMessage(error, l10n: context.l10n),
      tone: AppFeedbackTone.error,
    );
    return;
  }

  if (ref.read(homeEntrySelectionProvider).isActive) {
    ref.invalidate(homePinnedEntryIdsProvider);
  } else {
    refreshHomeIndexCaches(ref);
  }

  if (!context.mounted) {
    return;
  }
  showAppFeedbackSnackBar(
    context,
    pin
        ? context.l10n.homePinEntriesSuccess(count)
        : context.l10n.homeUnpinEntriesSuccess(count),
  );
}

/// 選取集合中的項目是否全部已釘選。
bool homeSelectionAllPinned(Set<EntryId> selectedIds, Set<EntryId> pinnedIds) {
  return selectedIds.isNotEmpty && selectedIds.every(pinnedIds.contains);
}
