import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/diary_organization/diary_organization.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/diary_organization/diary_organization_store.dart';

class FailingOrganizationStore extends DiaryOrganizationStore {
  FailingOrganizationStore({
    required super.paths,
    required super.crypto,
    required super.repository,
  });

  bool failSaves = false;

  @override
  Future<void> save(
    DiaryOrganization draft,
    UnlockedVaultSession session, {
    bool Function()? isCurrent,
  }) async {
    if (failSaves) throw StateError('無法寫入整理稿');
    await super.save(draft, session, isCurrent: isCurrent);
  }

  @override
  Future<DiaryEntry?> apply(
    DiaryOrganization draft,
    UnlockedVaultSession session, {
    void Function()? ensureCurrent,
  }) async {
    throw StateError('無法寫入日記');
  }
}
