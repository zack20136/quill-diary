import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/l10n/l10n.dart';

String relationshipTypeLabel(RelationshipType type, String languageCode) =>
    type.labelForLanguageCode(languageCode);

String personFriendlinessLabel(AppLocalizations l10n, int level) =>
    switch (level) {
      1 => l10n.peopleFriendlinessLevel1,
      2 => l10n.peopleFriendlinessLevel2,
      3 => l10n.peopleFriendlinessLevel3,
      4 => l10n.peopleFriendlinessLevel4,
      _ => l10n.peopleFriendlinessLevel5,
    };
