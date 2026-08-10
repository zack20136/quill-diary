import '../../domain/people/person.dart';
import '../../l10n/l10n.dart';

/// 依語系取得人物關係的顯示文字。
String personRelationshipLabel(
  AppLocalizations l10n,
  PersonRelationship relationship,
) {
  return switch (relationship) {
    PersonRelationship.family => l10n.peopleRelationFamily,
    PersonRelationship.partner => l10n.peopleRelationPartner,
    PersonRelationship.friend => l10n.peopleRelationFriend,
    PersonRelationship.classmate => l10n.peopleRelationClassmate,
    PersonRelationship.colleague => l10n.peopleRelationColleague,
    PersonRelationship.collaborator => l10n.peopleRelationCollaborator,
    PersonRelationship.other => l10n.peopleRelationOther,
  };
}

/// 依語系取得熟悉程度的顯示文字。
String personFriendlinessLabel(AppLocalizations l10n, int level) =>
    switch (level) {
      1 => l10n.peopleFriendlinessLevel1,
      2 => l10n.peopleFriendlinessLevel2,
      3 => l10n.peopleFriendlinessLevel3,
      4 => l10n.peopleFriendlinessLevel4,
      _ => l10n.peopleFriendlinessLevel5,
    };
