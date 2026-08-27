import 'package:flutter/material.dart';

import 'package:quill_diary/application/session/session_timeout_policy.dart';
import 'package:quill_diary/domain/shared/vault_backup_policy.dart';
import 'package:quill_diary/l10n/l10n.dart';

@immutable
class AboutPageTabSpec {
  const AboutPageTabSpec({
    required this.label,
    required this.heroIcon,
    required this.heroTitle,
    required this.heroBody,
    required this.chips,
    required this.sections,
  });

  final String label;
  final IconData heroIcon;
  final String heroTitle;
  final String heroBody;
  final List<String> chips;
  final List<AboutPageSectionSpec> sections;
}

@immutable
class AboutPageSectionSpec {
  const AboutPageSectionSpec({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<AboutPageItemSpec> items;
}

@immutable
class AboutPageItemSpec {
  const AboutPageItemSpec({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

List<AboutPageTabSpec> buildAboutPageTabSpecs(
  AppLocalizations l10n,
  Duration sessionTimeout,
) => <AboutPageTabSpec>[
  _introTab(l10n),
  _unlockSessionTab(l10n, sessionTimeout),
  _encryptionTab(l10n),
  _searchIndexTab(l10n),
  _editorTab(l10n),
  _peopleTab(l10n),
  _backupRestoreTab(l10n),
];

AboutPageItemSpec _item(IconData icon, String title, String body) =>
    AboutPageItemSpec(icon: icon, title: title, body: body);

AboutPageSectionSpec _section({
  required String title,
  required String subtitle,
  required List<AboutPageItemSpec> items,
}) => AboutPageSectionSpec(title: title, subtitle: subtitle, items: items);

AboutPageTabSpec _tab({
  required String label,
  required IconData heroIcon,
  required String heroTitle,
  required String heroBody,
  required List<String> chips,
  required List<AboutPageSectionSpec> sections,
}) => AboutPageTabSpec(
  label: label,
  heroIcon: heroIcon,
  heroTitle: heroTitle,
  heroBody: heroBody,
  chips: chips,
  sections: sections,
);

AboutPageTabSpec _introTab(AppLocalizations l10n) => _tab(
  label: l10n.aboutTabIntroLabel,
  heroIcon: Icons.menu_book_rounded,
  heroTitle: l10n.aboutTabIntroHeroTitle,
  heroBody: l10n.aboutTabIntroHeroBody,
  chips: <String>[
    l10n.aboutTabIntroChip0, // 資料留在裝置
    l10n.aboutTabIntroChip3, // 完整加密備份
    l10n.aboutTabIntroChip2, // 全文搜尋
    l10n.aboutTabIntroChip4, // 可攜式匯出
    l10n.aboutTabIntroChip1, // Markdown / HTML
  ],
  sections: <AboutPageSectionSpec>[
    _section(
      title: l10n.aboutTabIntroSection0Title,
      subtitle: l10n.aboutTabIntroSection0Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.lock_outline_rounded,
          l10n.aboutTabIntroSection0Item0Title,
          l10n.aboutTabIntroSection0Item0Body,
        ),
        _item(
          Icons.no_accounts_rounded,
          l10n.aboutTabIntroSection0Item1Title,
          l10n.aboutTabIntroSection0Item1Body,
        ),
        _item(
          Icons.shield_outlined,
          l10n.aboutTabIntroSection0Item2Title,
          l10n.aboutTabIntroSection0Item2Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabIntroSection1Title,
      subtitle: l10n.aboutTabIntroSection1Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.edit_note_rounded,
          l10n.aboutTabIntroSection1Item0Title,
          l10n.aboutTabIntroSection1Item0Body,
        ),
        _item(
          Icons.dashboard_outlined,
          l10n.aboutTabIntroSection1Item1Title,
          l10n.aboutTabIntroSection1Item1Body,
        ),
        _item(
          Icons.search_rounded,
          l10n.aboutTabIntroSection1Item2Title,
          l10n.aboutTabIntroSection1Item2Body,
        ),
        _item(
          Icons.outbox_outlined,
          l10n.aboutTabIntroSection1Item3Title,
          l10n.aboutTabIntroSection1Item3Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabIntroSection2Title,
      subtitle: l10n.aboutTabIntroSection2Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.key_outlined,
          l10n.aboutTabIntroSection2Item0Title,
          l10n.aboutTabIntroSection2Item0Body,
        ),
        _item(
          Icons.archive_outlined,
          l10n.aboutTabIntroSection2Item1Title,
          l10n.aboutTabIntroSection2Item1Body,
        ),
        _item(
          Icons.description_outlined,
          l10n.aboutTabIntroSection2Item2Title,
          l10n.aboutTabIntroSection2Item2Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabIntroSection3Title,
      subtitle: l10n.aboutTabIntroSection3Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.code_rounded,
          l10n.aboutTabIntroSection3Item0Title,
          l10n.aboutTabIntroSection3Item0Body,
        ),
        _item(
          Icons.verified_outlined,
          l10n.aboutTabIntroSection3Item1Title,
          l10n.legalBrandDisclaimer,
        ),
      ],
    ),
  ],
);

AboutPageTabSpec _unlockSessionTab(
  AppLocalizations l10n,
  Duration sessionTimeout,
) => _tab(
  label: l10n.aboutTabUnlockSessionLabel,
  heroIcon: Icons.lock_person_rounded,
  heroTitle: l10n.aboutTabUnlockSessionHeroTitle,
  heroBody: l10n.aboutTabUnlockSessionHeroBody,
  chips: <String>[
    l10n.aboutTabUnlockSessionChip3, // 復原金鑰
    l10n.aboutTabUnlockSessionChip0, // 生物辨識
    l10n.aboutTabUnlockSessionChip1, // 螢幕鎖
    l10n.aboutTabUnlockSessionChip2, // 自動鎖定
  ],
  sections: <AboutPageSectionSpec>[
    _section(
      title: l10n.aboutTabUnlockSessionSection0Title,
      subtitle: l10n.aboutTabUnlockSessionSection0Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.lock_open_rounded,
          l10n.aboutTabUnlockSessionSection0Item0Title,
          l10n.aboutTabUnlockSessionSection0Item0Body,
        ),
        _item(
          Icons.lock_outline,
          l10n.aboutTabUnlockSessionSection0Item1Title,
          l10n.aboutTabUnlockSessionSection0Item1Body,
        ),
        _item(
          Icons.fingerprint_rounded,
          l10n.aboutTabUnlockSessionSection0Item2Title,
          l10n.aboutTabUnlockSessionSection0Item2Body,
        ),
        _item(
          Icons.fact_check_outlined,
          l10n.aboutTabUnlockSessionSection0Item3Title,
          l10n.aboutTabUnlockSessionSection0Item3Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabUnlockSessionSection1Title,
      subtitle: l10n.aboutTabUnlockSessionSection1Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.lock_open_rounded,
          l10n.aboutTabUnlockSessionSection1Item0Title,
          l10n.aboutTabUnlockSessionSection1Item0Body,
        ),
        _item(
          Icons.lock_clock_outlined,
          l10n.aboutTabUnlockSessionSection1Item1Title,
          l10n.settingsSessionTimeoutAboutBackgroundTimeoutBody(
            sessionBackgroundTimeoutLabel(sessionTimeout, l10n),
          ),
        ),
        _item(
          Icons.keyboard_return_rounded,
          l10n.aboutTabUnlockSessionSection1Item2Title,
          l10n.aboutTabUnlockSessionSection1Item2Body,
        ),
        _item(
          Icons.gpp_maybe_outlined,
          l10n.aboutTabUnlockSessionSection1Item3Title,
          l10n.aboutTabUnlockSessionSection1Item3Body,
        ),
        _item(
          Icons.lock_rounded,
          l10n.aboutTabUnlockSessionSection1Item4Title,
          l10n.aboutTabUnlockSessionSection1Item4Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabUnlockSessionSection2Title,
      subtitle: l10n.aboutTabUnlockSessionSection2Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.phone_android_rounded,
          l10n.aboutTabUnlockSessionSection2Item0Title,
          l10n.aboutTabUnlockSessionSection2Item0Body,
        ),
        _item(
          Icons.link_off_rounded,
          l10n.aboutTabUnlockSessionSection2Item1Title,
          l10n.aboutTabUnlockSessionSection2Item1Body,
        ),
        _item(
          Icons.key_outlined,
          l10n.aboutTabUnlockSessionSection2Item2Title,
          l10n.aboutTabUnlockSessionSection2Item2Body,
        ),
      ],
    ),
  ],
);

AboutPageTabSpec _encryptionTab(AppLocalizations l10n) => _tab(
  label: l10n.aboutTabEncryptionLabel,
  heroIcon: Icons.enhanced_encryption_outlined,
  heroTitle: l10n.aboutTabEncryptionHeroTitle,
  heroBody: l10n.aboutTabEncryptionHeroBody,
  chips: <String>[
    l10n.aboutTabEncryptionChip0, // 本機加密
    l10n.aboutTabEncryptionChip2, // AES-256-GCM
    l10n.aboutTabEncryptionChip3, // Argon2id
    l10n.aboutTabEncryptionChip1, // LDJ2
    l10n.aboutTabEncryptionChip4, // 可信裝置
    l10n.aboutTabEncryptionChip5, // 裝置安全儲存
  ],
  sections: <AboutPageSectionSpec>[
    _section(
      title: l10n.aboutTabEncryptionSection0Title,
      subtitle: l10n.aboutTabEncryptionSection0Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.enhanced_encryption_outlined,
          l10n.aboutTabEncryptionSection0Item0Title,
          l10n.aboutTabEncryptionSection0Item0Body,
        ),
        _item(
          Icons.gpp_bad_outlined,
          l10n.aboutTabEncryptionSection0Item1Title,
          l10n.aboutTabEncryptionSection0Item1Body,
        ),
        _item(
          Icons.layers_outlined,
          l10n.aboutTabEncryptionSection0Item2Title,
          l10n.aboutTabEncryptionSection0Item2Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabEncryptionSection1Title,
      subtitle: l10n.aboutTabEncryptionSection1Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.phonelink_lock_outlined,
          l10n.aboutTabEncryptionSection1Item0Title,
          l10n.aboutTabEncryptionSection1Item0Body,
        ),
        _item(
          Icons.key_outlined,
          l10n.aboutTabEncryptionSection1Item1Title,
          l10n.aboutTabEncryptionSection1Item1Body,
        ),
        _item(
          Icons.fact_check_outlined,
          l10n.aboutTabEncryptionSection1Item2Title,
          l10n.aboutTabEncryptionSection1Item2Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabEncryptionSection2Title,
      subtitle: l10n.aboutTabEncryptionSection2Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.file_upload_outlined,
          l10n.aboutTabEncryptionSection2Item0Title,
          l10n.aboutTabEncryptionSection2Item0Body,
        ),
        _item(
          Icons.password_rounded,
          l10n.aboutTabEncryptionSection2Item1Title,
          l10n.aboutTabEncryptionSection2Item1Body,
        ),
        _item(
          Icons.security_outlined,
          l10n.aboutTabEncryptionSection2Item2Title,
          l10n.aboutTabEncryptionSection2Item2Body,
        ),
      ],
    ),
  ],
);

AboutPageTabSpec _searchIndexTab(AppLocalizations l10n) => _tab(
  label: l10n.aboutTabSearchIndexLabel,
  heroIcon: Icons.manage_search_rounded,
  heroTitle: l10n.aboutTabSearchIndexHeroTitle,
  heroBody: l10n.aboutTabSearchIndexHeroBody,
  chips: <String>[
    l10n.aboutTabSearchIndexChip0, // 標題/內文搜尋
    l10n.aboutTabSearchIndexChip1, // 加密索引
    l10n.aboutTabSearchIndexChip2, // 解鎖期間可用
    l10n.aboutTabSearchIndexChip3, // 可重建
  ],
  sections: <AboutPageSectionSpec>[
    _section(
      title: l10n.aboutTabSearchIndexSection0Title,
      subtitle: l10n.aboutTabSearchIndexSection0Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.search_rounded,
          l10n.aboutTabSearchIndexSection0Item0Title,
          l10n.aboutTabSearchIndexSection0Item0Body,
        ),
        _item(
          Icons.article_outlined,
          l10n.aboutTabSearchIndexSection0Item1Title,
          l10n.aboutTabSearchIndexSection0Item1Body,
        ),
        _item(
          Icons.lock_outline_rounded,
          l10n.aboutTabSearchIndexSection0Item2Title,
          l10n.aboutTabSearchIndexSection0Item2Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabSearchIndexSection1Title,
      subtitle: l10n.aboutTabSearchIndexSection1Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.manage_search_outlined,
          l10n.aboutTabSearchIndexSection1Item0Title,
          l10n.aboutTabSearchIndexSection1Item0Body,
        ),
        _item(
          Icons.save_outlined,
          l10n.aboutTabSearchIndexSection1Item1Title,
          l10n.aboutTabSearchIndexSection1Item1Body,
        ),
        _item(
          Icons.refresh_rounded,
          l10n.aboutTabSearchIndexSection1Item2Title,
          l10n.aboutTabSearchIndexSection1Item2Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabSearchIndexSection2Title,
      subtitle: l10n.aboutTabSearchIndexSection2Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.lock_open_rounded,
          l10n.aboutTabSearchIndexSection2Item0Title,
          l10n.aboutTabSearchIndexSection2Item0Body,
        ),
        _item(
          Icons.search_off_outlined,
          l10n.aboutTabSearchIndexSection2Item1Title,
          l10n.aboutTabSearchIndexSection2Item1Body,
        ),
        _item(
          Icons.storage_rounded,
          l10n.aboutTabSearchIndexSection2Item2Title,
          l10n.aboutTabSearchIndexSection2Item2Body,
        ),
      ],
    ),
  ],
);

AboutPageTabSpec _editorTab(AppLocalizations l10n) => _tab(
  label: l10n.aboutTabEditorLabel,
  heroIcon: Icons.edit_note_rounded,
  heroTitle: l10n.aboutTabEditorHeroTitle,
  heroBody: l10n.aboutTabEditorHeroBody,
  chips: <String>[
    l10n.aboutTabEditorChip2, // 自動草稿
    l10n.aboutTabEditorChip3, // 未儲存提醒
    l10n.aboutTabEditorChip1, // 圖片附件
    l10n.aboutTabEditorChip0, // 可匯出 Markdown
  ],
  sections: <AboutPageSectionSpec>[
    _section(
      title: l10n.aboutTabEditorSection0Title,
      subtitle: l10n.aboutTabEditorSection0Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.edit_outlined,
          l10n.aboutTabEditorSection0Item0Title,
          l10n.aboutTabEditorSection0Item0Body,
        ),
        _item(
          Icons.event_note_rounded,
          l10n.aboutTabEditorSection0Item1Title,
          l10n.aboutTabEditorSection0Item1Body,
        ),
        _item(
          Icons.local_offer_outlined,
          l10n.aboutTabEditorSection0Item2Title,
          l10n.aboutTabEditorSection0Item2Body,
        ),
        _item(
          Icons.checklist_rounded,
          l10n.aboutTabEditorSection0Item3Title,
          l10n.aboutTabEditorSection0Item3Body,
        ),
        _item(
          Icons.attach_file,
          l10n.aboutTabEditorSection0Item4Title,
          l10n.aboutTabEditorSection0Item4Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabEditorSection1Title,
      subtitle: l10n.aboutTabEditorSection1Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.save_as_outlined,
          l10n.aboutTabEditorSection1Item0Title,
          l10n.aboutTabEditorSection1Item0Body,
        ),
        _item(
          Icons.restore_rounded,
          l10n.aboutTabEditorSection1Item1Title,
          l10n.aboutTabEditorSection1Item1Body,
        ),
        _item(
          Icons.auto_delete_outlined,
          l10n.aboutTabEditorSection1Item2Title,
          l10n.aboutTabEditorSection1Item2Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabEditorSection2Title,
      subtitle: l10n.aboutTabEditorSection2Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.search_off_outlined,
          l10n.aboutTabEditorSection2Item0Title,
          l10n.aboutTabEditorSection2Item0Body,
        ),
        _item(
          Icons.archive_outlined,
          l10n.aboutTabEditorSection2Item1Title,
          l10n.aboutTabEditorSection2Item1Body,
        ),
        _item(
          Icons.pending_actions_outlined,
          l10n.aboutTabEditorSection2Item2Title,
          l10n.aboutTabEditorSection2Item2Body,
        ),
      ],
    ),
  ],
);

AboutPageTabSpec _peopleTab(AppLocalizations l10n) => _tab(
  label: l10n.aboutTabPeopleLabel,
  heroIcon: Icons.people_alt_outlined,
  heroTitle: l10n.aboutTabPeopleHeroTitle,
  heroBody: l10n.aboutTabPeopleHeroBody,
  chips: <String>[
    l10n.aboutTabPeopleChip3, // @ 快速插入
    l10n.aboutTabPeopleChip0, // 姓名與別名
    l10n.aboutTabPeopleChip2, // 提及統計
    l10n.aboutTabPeopleChip1, // 關係與備註
  ],
  sections: <AboutPageSectionSpec>[
    _section(
      title: l10n.aboutTabPeopleSection0Title,
      subtitle: l10n.aboutTabPeopleSection0Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.badge_outlined,
          l10n.aboutTabPeopleSection0Item0Title,
          l10n.aboutTabPeopleSection0Item0Body,
        ),
        _item(
          Icons.handshake_outlined,
          l10n.aboutTabPeopleSection0Item1Title,
          l10n.aboutTabPeopleSection0Item1Body,
        ),
        _item(
          Icons.cake_outlined,
          l10n.aboutTabPeopleSection0Item2Title,
          l10n.aboutTabPeopleSection0Item2Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabPeopleSection1Title,
      subtitle: l10n.aboutTabPeopleSection1Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.auto_graph_outlined,
          l10n.aboutTabPeopleSection1Item0Title,
          l10n.aboutTabPeopleSection1Item0Body,
        ),
        _item(
          Icons.history_rounded,
          l10n.aboutTabPeopleSection1Item1Title,
          l10n.aboutTabPeopleSection1Item1Body,
        ),
        _item(
          Icons.alternate_email_rounded,
          l10n.aboutTabPeopleSection1Item2Title,
          l10n.aboutTabPeopleSection1Item2Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabPeopleSection2Title,
      subtitle: l10n.aboutTabPeopleSection2Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.edit_note_outlined,
          l10n.aboutTabPeopleSection2Item0Title,
          l10n.aboutTabPeopleSection2Item0Body,
        ),
        _item(
          Icons.person_remove_outlined,
          l10n.aboutTabPeopleSection2Item1Title,
          l10n.aboutTabPeopleSection2Item1Body,
        ),
        _item(
          Icons.rule_outlined,
          l10n.aboutTabPeopleSection2Item2Title,
          l10n.aboutTabPeopleSection2Item2Body,
        ),
      ],
    ),
  ],
);

AboutPageTabSpec _backupRestoreTab(AppLocalizations l10n) => _tab(
  label: l10n.aboutTabBackupRestoreLabel,
  heroIcon: Icons.storage_rounded,
  heroTitle: l10n.aboutTabBackupRestoreHeroTitle,
  heroBody: l10n.aboutTabBackupRestoreHeroBody,
  chips: <String>[
    l10n.aboutTabBackupRestoreChip0, // 完整加密備份
    l10n.aboutTabBackupRestoreChip1, // Google Drive
    l10n.aboutTabBackupRestoreChip2, // Markdown
    l10n.aboutTabBackupRestoreChip3, // HTML
  ],
  sections: <AboutPageSectionSpec>[
    _section(
      title: l10n.aboutTabBackupRestoreSection0Title,
      subtitle: l10n.aboutTabBackupRestoreSection0Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.archive_outlined,
          l10n.aboutTabBackupRestoreSection0Item0Title,
          l10n.aboutTabBackupRestoreSection0Item0Body,
        ),
        _item(
          Icons.fact_check_outlined,
          l10n.aboutTabBackupRestoreSection0Item1Title,
          l10n.aboutTabBackupRestoreSection0Item1Body,
        ),
        _item(
          Icons.history_rounded,
          l10n.aboutTabBackupRestoreSection0Item2Title,
          l10n.aboutTabBackupRestoreSection0Item2Body(
            VaultBackupPolicy.retainCount,
          ),
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabBackupRestoreSection1Title,
      subtitle: l10n.aboutTabBackupRestoreSection1Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.swap_horiz_rounded,
          l10n.aboutTabBackupRestoreSection1Item0Title,
          l10n.aboutTabBackupRestoreSection1Item0Body,
        ),
        _item(
          Icons.refresh_rounded,
          l10n.aboutTabBackupRestoreSection1Item1Title,
          l10n.aboutTabBackupRestoreSection1Item1Body,
        ),
        _item(
          Icons.key_outlined,
          l10n.aboutTabBackupRestoreSection1Item2Title,
          l10n.aboutTabBackupRestoreSection1Item2Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabBackupRestoreSection2Title,
      subtitle: l10n.aboutTabBackupRestoreSection2Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.file_download_outlined,
          l10n.aboutTabBackupRestoreSection2Item0Title,
          l10n.aboutTabBackupRestoreSection2Item0Body,
        ),
        _item(
          Icons.file_upload_outlined,
          l10n.aboutTabBackupRestoreSection2Item1Title,
          l10n.aboutTabBackupRestoreSection2Item1Body,
        ),
        _item(
          Icons.cloud_off_rounded,
          l10n.aboutTabBackupRestoreSection2Item2Title,
          l10n.aboutTabBackupRestoreSection2Item2Body,
        ),
      ],
    ),
    _section(
      title: l10n.aboutTabBackupRestoreSection3Title,
      subtitle: l10n.aboutTabBackupRestoreSection3Subtitle,
      items: <AboutPageItemSpec>[
        _item(
          Icons.drafts_outlined,
          l10n.aboutTabBackupRestoreSection3Item0Title,
          l10n.aboutTabBackupRestoreSection3Item0Body,
        ),
        _item(
          Icons.description_outlined,
          l10n.aboutTabBackupRestoreSection3Item1Title,
          l10n.aboutTabBackupRestoreSection3Item1Body,
        ),
        _item(
          Icons.alt_route_rounded,
          l10n.aboutTabBackupRestoreSection3Item2Title,
          l10n.aboutTabBackupRestoreSection3Item2Body,
        ),
      ],
    ),
  ],
);
