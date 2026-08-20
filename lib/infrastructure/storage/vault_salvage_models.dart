import 'package:quill_diary/application/editor/editor_draft_models.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';

/// 一次性手動修復草稿；成功儲存新日記後才 retire 舊問題檔。
class VaultSalvageDraft {
  const VaultSalvageDraft({
    required this.token,
    required this.newEntryId,
    required this.record,
    required this.sourceFindings,
    this.hasSourceDate = false,
  });

  /// 與 [newEntryId] 相同，用作草稿 key 與路由參數。
  final String token;
  final EntryId newEntryId;
  final EditorDraftRecord record;
  final List<VaultFinding> sourceFindings;
  final bool hasSourceDate;

  static String draftKeyForToken(String token) => '__salvage_$token';

  bool get hasSalvageableContent {
    final String? title = record.title?.trim();
    final String body = record.markdownBody.trim();
    final String date = record.dateValue.trim();
    return (title != null && title.isNotEmpty) ||
        body.isNotEmpty ||
        (hasSourceDate && DateOnly.tryParse(date) != null);
  }
}
