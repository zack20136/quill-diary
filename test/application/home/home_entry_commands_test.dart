import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/home/home_entry_commands.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

import '../../helpers/session/fake_session_vault_repository.dart';

void main() {
  testWidgets('setHomeEntriesPinned 只將指定日記交給 repository', (
    WidgetTester tester,
  ) async {
    final _RecordingHomeRepository repository = _RecordingHomeRepository();
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vaultRepositoryProvider.overrideWithValue(repository)],
        child: Consumer(
          builder: (BuildContext context, WidgetRef currentRef, Widget? _) {
            ref = currentRef;
            return const SizedBox();
          },
        ),
      ),
    );
    await setHomeEntriesPinned(ref, <EntryId>{
      'entry-a',
      'entry-b',
    }, pinned: true);

    expect(repository.pinnedIds, <EntryId>{'entry-a', 'entry-b'});
    expect(repository.pinned, isTrue);
  });
}

class _RecordingHomeRepository extends FakeSessionVaultRepository {
  Set<EntryId>? pinnedIds;
  bool? pinned;

  @override
  Future<void> setEntriesPinned(
    Iterable<EntryId> entryIds, {
    required bool pinned,
  }) async {
    pinnedIds = entryIds.toSet();
    this.pinned = pinned;
  }
}
