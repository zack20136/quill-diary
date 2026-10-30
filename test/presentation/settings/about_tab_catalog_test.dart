import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/session/session_timeout_policy.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/settings/about_tab_catalog.dart';

import '../../helpers/shared/test_l10n.dart';

void main() {
  test('中英文分頁順序固定且所有內容皆完整', () {
    for (final AppLocalizations l10n in <AppLocalizations>[
      testZhL10n,
      testEnL10n,
    ]) {
      final List<AboutPageTabSpec> tabs = buildAboutPageTabSpecs(
        l10n,
        kDefaultSessionBackgroundTimeout,
      );

      expect(
        tabs.map((AboutPageTabSpec tab) => tab.label).toList(growable: false),
        <String>[
          l10n.aboutTabIntroLabel,
          l10n.aboutTabEncryptionLabel,
          l10n.aboutTabUnlockSessionLabel,
          l10n.aboutTabBackupRestoreLabel,
          l10n.aboutTabEditorLabel,
          l10n.aboutTabPeopleLabel,
          l10n.aboutTabSearchIndexLabel,
        ],
      );
      expect(tabs.map((AboutPageTabSpec tab) => tab.heroTitle), <String>[
        l10n.aboutTabIntroHeroTitle,
        l10n.aboutTabEncryptionHeroTitle,
        l10n.aboutTabUnlockSessionHeroTitle,
        l10n.aboutTabBackupRestoreHeroTitle,
        l10n.aboutTabEditorHeroTitle,
        l10n.aboutTabPeopleHeroTitle,
        l10n.aboutTabSearchIndexHeroTitle,
      ]);
      expect(tabs.map((AboutPageTabSpec tab) => tab.heroBody), <String>[
        l10n.aboutTabIntroHeroBody,
        l10n.aboutTabEncryptionHeroBody,
        l10n.aboutTabUnlockSessionHeroBody,
        l10n.aboutTabBackupRestoreHeroBody,
        l10n.aboutTabEditorHeroBody,
        l10n.aboutTabPeopleHeroBody,
        l10n.aboutTabSearchIndexHeroBody,
      ]);

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
    }
  });

  test('人物名冊介紹位於寫日記與搜尋之間並含 hero、chips 與 sections', () {
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
    expect(tabs[peopleIndex + 1].label, l10n.aboutTabSearchIndexLabel);

    final AboutPageTabSpec peopleTab = tabs[peopleIndex];
    expect(peopleTab.heroTitle, l10n.aboutTabPeopleHeroTitle);
    expect(peopleTab.chips, <String>[
      l10n.aboutTabPeopleChip0,
      l10n.aboutTabPeopleChip1,
      l10n.aboutTabPeopleChip2,
      l10n.aboutTabPeopleChip3,
    ]);
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

  test('簡介包含個人化提示', () {
    final AppLocalizations l10n = testL10n;
    final AboutPageTabSpec introTab = buildAboutPageTabSpecs(
      l10n,
      kDefaultSessionBackgroundTimeout,
    ).first;

    final AboutPageItemSpec personalizationItem = introTab.sections
        .expand((AboutPageSectionSpec section) => section.items)
        .singleWhere(
          (AboutPageItemSpec item) =>
              item.title == l10n.aboutTabIntroSection1Item4Title,
        );

    expect(personalizationItem.body, l10n.aboutTabIntroSection1Item4Body);
    expect(personalizationItem.body, contains('圖片品質'));
  });

  test('備份分頁先顯示完整換機指南', () {
    final AppLocalizations l10n = testL10n;
    final AboutPageTabSpec backupTab =
        buildAboutPageTabSpecs(
          l10n,
          kDefaultSessionBackgroundTimeout,
        ).singleWhere(
          (AboutPageTabSpec tab) =>
              tab.label == l10n.aboutTabBackupRestoreLabel,
        );
    final AboutPageSectionSpec transferSection = backupTab.sections.first;

    expect(transferSection.title, l10n.aboutTabBackupRestoreSection0Title);
    expect(
      transferSection.items.map((AboutPageItemSpec item) => item.title),
      <String>[
        l10n.aboutTabBackupRestoreSection0Item0Title,
        l10n.aboutTabBackupRestoreSection0Item1Title,
        l10n.aboutTabBackupRestoreSection0Item2Title,
        l10n.aboutTabBackupRestoreSection0Item3Title,
      ],
    );
    expect(transferSection.items[0].body, contains('草稿'));
    expect(transferSection.items[1].body, contains('匯入外部備份'));
    expect(transferSection.items[2].body, contains('同一帳戶'));
    expect(transferSection.items[3].body, contains('舊備份'));
    expect(transferSection.items[3].body, contains('釘選'));
  });

  test('中英文備份分頁依序區分匯入匯出、交換與使用邊界', () {
    for (final AppLocalizations l10n in <AppLocalizations>[
      testZhL10n,
      testEnL10n,
    ]) {
      final AboutPageTabSpec backupTab =
          buildAboutPageTabSpecs(
            l10n,
            kDefaultSessionBackgroundTimeout,
          ).singleWhere(
            (AboutPageTabSpec tab) =>
                tab.label == l10n.aboutTabBackupRestoreLabel,
          );

      expect(
        backupTab.sections.map((AboutPageSectionSpec section) => section.title),
        <String>[
          l10n.aboutTabBackupRestoreSection0Title,
          l10n.aboutTabBackupRestoreSection1Title,
          l10n.aboutTabBackupRestoreSection2Title,
          l10n.aboutTabBackupRestoreSection3Title,
          l10n.aboutTabBackupRestoreSection4Title,
          l10n.aboutTabBackupRestoreSection5Title,
        ],
      );
      expect(
        backupTab.sections[3].items.map((AboutPageItemSpec item) => item.title),
        <String>[
          l10n.aboutTabBackupRestoreSection3Item0Title,
          l10n.aboutTabBackupRestoreSection3Item1Title,
        ],
      );
      expect(
        backupTab.sections[4].items.map((AboutPageItemSpec item) => item.title),
        <String>[
          l10n.aboutTabBackupRestoreSection4Item0Title,
          l10n.aboutTabBackupRestoreSection4Item1Title,
          l10n.aboutTabBackupRestoreSection4Item2Title,
        ],
      );
      expect(
        backupTab.sections[5].items.map((AboutPageItemSpec item) => item.title),
        <String>[
          l10n.aboutTabBackupRestoreSection5Item0Title,
          l10n.aboutTabBackupRestoreSection5Item1Title,
        ],
      );
    }
  });

  test('交換說明涵蓋獨立副本與可辨識資訊邊界', () {
    final AboutPageTabSpec backupTab =
        buildAboutPageTabSpecs(
          testL10n,
          kDefaultSessionBackgroundTimeout,
        ).singleWhere(
          (AboutPageTabSpec tab) =>
              tab.label == testL10n.aboutTabBackupRestoreLabel,
        );
    final AboutPageSectionSpec exchangeSection = backupTab.sections[4];
    final String exchangeBody = exchangeSection.items[0].body;
    final String privacyBody = exchangeSection.items[1].body;
    final String externalToolBody = exchangeSection.items[2].body;

    expect(exchangeBody, contains('指定日記'));
    expect(exchangeBody, contains('匯入日記'));
    expect(exchangeBody, contains('新日記'));
    expect(exchangeBody, contains('重複'));
    expect(exchangeBody, contains('不會共同編輯或同步'));
    expect(privacyBody, contains('HTML 另可關閉圖片與附件'));
    expect(privacyBody, isNot(contains('Markdown 另可關閉圖片與附件')));
    expect('$privacyBody$externalToolBody', isNot(contains('去識別化')));
    expect('$privacyBody$externalToolBody', isNot(contains('匿名化')));
    expect(externalToolBody, contains('未登錄姓名'));
    expect(externalToolBody, contains('明文'));
    expect(externalToolBody, contains('所選工具的政策'));
  });

  test('關於頁精確區分復原金鑰、正式日記庫與備份結構檢查', () {
    final List<AboutPageTabSpec> tabs = buildAboutPageTabSpecs(
      testZhL10n,
      kDefaultSessionBackgroundTimeout,
    );
    final AboutPageTabSpec introTab = tabs[0];
    final AboutPageTabSpec encryptionTab = tabs[1];
    final AboutPageTabSpec unlockTab = tabs[2];
    final AboutPageTabSpec backupTab = tabs[3];

    expect(introTab.sections[1].items[3].body, contains('正式日記庫'));
    expect(introTab.sections[2].items[0].body, contains('不包含日記資料'));
    expect(
      encryptionTab.sections[0].items[0].body,
      contains('檔案內容以 AES-256-GCM 加密'),
    );
    expect(unlockTab.heroBody, contains('換機仍需完整備份'));
    expect(unlockTab.sections[2].items[0].body, contains('必須先取得完整備份'));
    expect(backupTab.sections[1].items[1].body, contains('基本結構符合完整備份格式'));
  });

  test('中英文人物與匯出說明採用提及篇數及有限隱私保護語意', () {
    final AboutPageTabSpec zhPeopleTab = buildAboutPageTabSpecs(
      testZhL10n,
      kDefaultSessionBackgroundTimeout,
    )[5];
    final AboutPageTabSpec enPeopleTab = buildAboutPageTabSpecs(
      testEnL10n,
      kDefaultSessionBackgroundTimeout,
    )[5];
    final AboutPageTabSpec zhBackupTab = buildAboutPageTabSpecs(
      testZhL10n,
      kDefaultSessionBackgroundTimeout,
    )[3];
    final AboutPageTabSpec enBackupTab = buildAboutPageTabSpecs(
      testEnL10n,
      kDefaultSessionBackgroundTimeout,
    )[3];

    expect(zhPeopleTab.sections[1].items[1].body, contains('提及日記篇數'));
    expect(zhPeopleTab.sections[1].items[1].body, contains('只計為一篇'));
    expect(
      enPeopleTab.sections[1].items[1].body,
      contains('Multiple mentions in one entry still count as one entry'),
    );
    expect(
      zhBackupTab.sections[4].items[2].body,
      allOf(contains('只會'), contains('其他線索仍可能辨識個人')),
    );
    expect(
      enBackupTab.sections[4].items[2].body,
      allOf(contains('only replaces'), contains('may still identify someone')),
    );
  });
}
