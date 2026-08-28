import '../../domain/people/relationship_type.dart';
import '../../l10n/l10n.dart';

/// 依目前語系取得關係類型顯示名。
String relationshipTypeLabel(
  RelationshipType type,
  String languageCode,
) => type.labelForLanguageCode(languageCode);

/// 依語系取得熟悉程度的顯示文字。
String personFriendlinessLabel(AppLocalizations l10n, int level) =>
    switch (level) {
      1 => l10n.peopleFriendlinessLevel1,
      2 => l10n.peopleFriendlinessLevel2,
      3 => l10n.peopleFriendlinessLevel3,
      4 => l10n.peopleFriendlinessLevel4,
      _ => l10n.peopleFriendlinessLevel5,
    };
