import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/infrastructure/database/index_database.dart';

void main() {
  test('合作夥伴篩選只保留具有該關係的人物', () {
    final DateTime now = DateTime(2026);
    final List<PersonListItem> items = buildPeopleListItems(
      catalog: <Person>[
        Person(
          id: 'collaborator',
          name: '合作對象',
          relationships: const <String>{BuiltinRelationshipIds.collaborator},
          createdAt: now,
          updatedAt: now,
        ),
        Person(
          id: 'friend',
          name: '朋友',
          relationships: const <String>{BuiltinRelationshipIds.friend},
          createdAt: now,
          updatedAt: now,
        ),
      ],
      statsMap: const <String, PersonMentionStats>{},
      statsReady: false,
    );

    final List<PersonListItem> filtered = filterPeopleListItems(
      items: items,
      query: '',
      relationships: const <String>{BuiltinRelationshipIds.collaborator},
      sort: PeopleListSort.name,
    );

    expect(filtered.map((PersonListItem item) => item.person.id), <String>[
      'collaborator',
    ]);
  });

  test('人物名冊離開最後一個訂閱者後會釋放 provider', () async {
    final _DisposeObserver observer = _DisposeObserver();
    final ProviderContainer container = ProviderContainer(
      observers: <ProviderObserver>[observer],
      overrides: [
        peopleCatalogProvider.overrideWith(
          (Ref ref) async => PeopleCatalog.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final ProviderSubscription<AsyncValue<PeopleCatalog>> subscription =
        container.listen(peopleCatalogProvider, (_, _) {});
    await container.read(peopleCatalogProvider.future);

    subscription.close();
    await container.pump();

    expect(observer.disposed, contains(peopleCatalogProvider));
  });
}

final class _DisposeObserver extends ProviderObserver {
  final List<Object> disposed = <Object>[];

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    disposed.add(context.provider);
  }
}
