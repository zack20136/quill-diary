import 'package:flutter/widgets.dart';

import '../../domain/security/unlocked_vault_session.dart';
import '../../domain/shared/value_objects.dart';
import 'tag_styles_store.dart';
import 'vault_repository.dart';

class VaultTagService {
  const VaultTagService(this._repository);

  final VaultRepository _repository;

  Future<List<TagCatalogItem>> listTagCatalog() => _repository.listTagCatalog();

  Future<Set<EntryId>> listPinnedEntryIds() => _repository.listPinnedEntryIds();

  Future<void> setEntriesPinned(
    Iterable<EntryId> entryIds, {
    required bool pinned,
  }) => _repository.setEntriesPinned(entryIds, pinned: pinned);

  Future<void> upsertTagCatalogItem(
    String label, {
    int? accentArgb,
    bool? accentIsCustom,
  }) => _repository.upsertTagCatalogItem(
    label,
    accentArgb: accentArgb,
    accentIsCustom: accentIsCustom,
  );

  Future<void> ensureTagCatalogLabels(Iterable<String> labels) =>
      _repository.ensureTagCatalogLabels(labels);

  Future<void> deleteTagCatalogItem(String label) =>
      _repository.deleteTagCatalogItem(label);

  Future<void> upsertTagAccentArgb(
    String tag,
    int accentArgb, {
    bool? accentIsCustom,
  }) => _repository.upsertTagAccentArgb(
    tag,
    accentArgb,
    accentIsCustom: accentIsCustom,
  );

  Future<void> deleteTagAccentArgb(String tag) =>
      _repository.deleteTagAccentArgb(tag);

  Future<bool> seedDefaultTagCatalogIfEmpty({required Locale locale}) =>
      _repository.seedDefaultTagCatalogIfEmpty(locale: locale);

  Future<int> renameTagCatalogItem(
    UnlockedVaultSession session, {
    required String fromLabel,
    required String toLabel,
    int? accentArgb,
    bool? accentIsCustom,
  }) => _repository.renameTagCatalogItem(
    session,
    fromLabel: fromLabel,
    toLabel: toLabel,
    accentArgb: accentArgb,
    accentIsCustom: accentIsCustom,
  );

  Future<int> removeTagFromAllEntries(
    UnlockedVaultSession session,
    String tag,
  ) => _repository.removeTagFromAllEntries(session, tag);

  Future<void> syncTagStylesBetweenVaultAndIndex() =>
      _repository.syncTagStylesBetweenVaultAndIndex();
}
