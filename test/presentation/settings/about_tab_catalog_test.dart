import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/session_timeout_policy.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/settings/about_tab_catalog.dart';

import '../../helpers/shared/test_l10n.dart';

void main() {
  test('分頁順序固定且各 tab 皆有 hero、chips 與 sections', () {
    final AppLocalizations l10n = testL10n;
    final List<AboutPageTabSpec> tabs = buildAboutPageTabSpecs(
      l10n,
      kDefaultSessionBackgroundTimeout,
    );

    expect(
      tabs.map((AboutPageTabSpec tab) => tab.label).toList(growable: false),
      <String>[
        l10n.aboutTabIntroLabel,
        l10n.aboutTabUnlockSessionLabel,
        l10n.aboutTabEncryptionLabel,
        l10n.aboutTabSearchIndexLabel,
        l10n.aboutTabEditorLabel,
        l10n.aboutTabPeopleLabel,
        l10n.aboutTabBackupRestoreLabel,
      ],
    );

    for (final AboutPageTabSpec tab in tabs) {
      expect(tab.heroTitle, isNotEmpty);
      expect(tab.heroBody, isNotEmpty);
      expect(tab.chips, isNotEmpty);
      expect(tab.sections, isNotEmpty);
      for (final AboutPageSectionSpec section in tab.sections) {
        expect(section.title, isNotEmpty);
        expect(section.subtitle, isNotEmpty);
        expect(section.items, isNotEmpty);
        for (final AboutPageItemSpec item in section.items) {
          expect(item.title, isNotEmpty);
          expect(item.body, isNotEmpty);
        }
      }
    }
  });

  test('人物管理介紹位於編輯器與備份之間並含 hero、chips 與 sections', () {
    final AppLocalizations l10n = testL10n;
    final List<AboutPageTabSpec> tabs = buildAboutPageTabSpecs(
      l10n,
      kDefaultSessionBackgroundTimeout,
    );

    final int peopleIndex = tabs.indexWhere(
      (AboutPageTabSpec tab) => tab.label == l10n.aboutTabPeopleLabel,
    );

    expect(
      tabs.where(
        (AboutPageTabSpec tab) => tab.label == l10n.aboutTabPeopleLabel,
      ),
      hasLength(1),
    );
    expect(tabs[peopleIndex - 1].label, l10n.aboutTabEditorLabel);
    expect(tabs[peopleIndex + 1].label, l10n.aboutTabBackupRestoreLabel);

    final AboutPageTabSpec peopleTab = tabs[peopleIndex];
    expect(peopleTab.heroTitle, l10n.aboutTabPeopleHeroTitle);
    expect(
      peopleTab.chips,
      <String>[
        l10n.aboutTabPeopleChip3,
        l10n.aboutTabPeopleChip0,
        l10n.aboutTabPeopleChip2,
        l10n.aboutTabPeopleChip1,
      ],
    );
    expect(
      peopleTab.sections.map((AboutPageSectionSpec section) => section.title),
      <String>[
        l10n.aboutTabPeopleSection0Title,
        l10n.aboutTabPeopleSection1Title,
        l10n.aboutTabPeopleSection2Title,
      ],
    );
    expect(
      tabs.first.sections[1].items[1].body,
      l10n.aboutTabIntroSection1Item1Body,
    );
    expect(tabs.first.sections[1].items[1].body, contains('人物'));
  });
}
