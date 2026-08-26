import 'package:flutter/material.dart';

import 'package:quill_diary/domain/shared/vault_backup_policy.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/application/session/session_timeout_policy.dart';

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
  AboutPageTabSpec(
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
      AboutPageSectionSpec(
        title: l10n.aboutTabIntroSection0Title,
        subtitle: l10n.aboutTabIntroSection0Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.lock_outline_rounded,
            title: l10n.aboutTabIntroSection0Item0Title,
            body: l10n.aboutTabIntroSection0Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.no_accounts_rounded,
            title: l10n.aboutTabIntroSection0Item1Title,
            body: l10n.aboutTabIntroSection0Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.shield_outlined,
            title: l10n.aboutTabIntroSection0Item2Title,
            body: l10n.aboutTabIntroSection0Item2Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabIntroSection1Title,
        subtitle: l10n.aboutTabIntroSection1Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.edit_note_rounded,
            title: l10n.aboutTabIntroSection1Item0Title,
            body: l10n.aboutTabIntroSection1Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.dashboard_outlined,
            title: l10n.aboutTabIntroSection1Item1Title,
            body: l10n.aboutTabIntroSection1Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.search_rounded,
            title: l10n.aboutTabIntroSection1Item2Title,
            body: l10n.aboutTabIntroSection1Item2Body,
          ),
          AboutPageItemSpec(
            icon: Icons.outbox_outlined,
            title: l10n.aboutTabIntroSection1Item3Title,
            body: l10n.aboutTabIntroSection1Item3Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabIntroSection2Title,
        subtitle: l10n.aboutTabIntroSection2Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.key_outlined,
            title: l10n.aboutTabIntroSection2Item0Title,
            body: l10n.aboutTabIntroSection2Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.archive_outlined,
            title: l10n.aboutTabIntroSection2Item1Title,
            body: l10n.aboutTabIntroSection2Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.description_outlined,
            title: l10n.aboutTabIntroSection2Item2Title,
            body: l10n.aboutTabIntroSection2Item2Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabIntroSection3Title,
        subtitle: l10n.aboutTabIntroSection3Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.code_rounded,
            title: l10n.aboutTabIntroSection3Item0Title,
            body: l10n.aboutTabIntroSection3Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.verified_outlined,
            title: l10n.aboutTabIntroSection3Item1Title,
            body: l10n.legalBrandDisclaimer,
          ),
        ],
      ),
    ],
  ),
  AboutPageTabSpec(
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
      AboutPageSectionSpec(
        title: l10n.aboutTabUnlockSessionSection0Title,
        subtitle: l10n.aboutTabUnlockSessionSection0Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.lock_open_rounded,
            title: l10n.aboutTabUnlockSessionSection0Item0Title,
            body: l10n.aboutTabUnlockSessionSection0Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.lock_outline,
            title: l10n.aboutTabUnlockSessionSection0Item1Title,
            body: l10n.aboutTabUnlockSessionSection0Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.fingerprint_rounded,
            title: l10n.aboutTabUnlockSessionSection0Item2Title,
            body: l10n.aboutTabUnlockSessionSection0Item2Body,
          ),
          AboutPageItemSpec(
            icon: Icons.fact_check_outlined,
            title: l10n.aboutTabUnlockSessionSection0Item3Title,
            body: l10n.aboutTabUnlockSessionSection0Item3Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabUnlockSessionSection1Title,
        subtitle: l10n.aboutTabUnlockSessionSection1Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.lock_open_rounded,
            title: l10n.aboutTabUnlockSessionSection1Item0Title,
            body: l10n.aboutTabUnlockSessionSection1Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.lock_clock_outlined,
            title: l10n.aboutTabUnlockSessionSection1Item1Title,
            body: l10n.settingsSessionTimeoutAboutBackgroundTimeoutBody(
              sessionBackgroundTimeoutLabel(sessionTimeout, l10n),
            ),
          ),
          AboutPageItemSpec(
            icon: Icons.keyboard_return_rounded,
            title: l10n.aboutTabUnlockSessionSection1Item2Title,
            body: l10n.aboutTabUnlockSessionSection1Item2Body,
          ),
          AboutPageItemSpec(
            icon: Icons.gpp_maybe_outlined,
            title: l10n.aboutTabUnlockSessionSection1Item3Title,
            body: l10n.aboutTabUnlockSessionSection1Item3Body,
          ),
          AboutPageItemSpec(
            icon: Icons.lock_rounded,
            title: l10n.aboutTabUnlockSessionSection1Item4Title,
            body: l10n.aboutTabUnlockSessionSection1Item4Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabUnlockSessionSection2Title,
        subtitle: l10n.aboutTabUnlockSessionSection2Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.phone_android_rounded,
            title: l10n.aboutTabUnlockSessionSection2Item0Title,
            body: l10n.aboutTabUnlockSessionSection2Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.link_off_rounded,
            title: l10n.aboutTabUnlockSessionSection2Item1Title,
            body: l10n.aboutTabUnlockSessionSection2Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.key_outlined,
            title: l10n.aboutTabUnlockSessionSection2Item2Title,
            body: l10n.aboutTabUnlockSessionSection2Item2Body,
          ),
        ],
      ),
    ],
  ),
  AboutPageTabSpec(
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
      AboutPageSectionSpec(
        title: l10n.aboutTabEncryptionSection0Title,
        subtitle: l10n.aboutTabEncryptionSection0Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.enhanced_encryption_outlined,
            title: l10n.aboutTabEncryptionSection0Item0Title,
            body: l10n.aboutTabEncryptionSection0Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.gpp_bad_outlined,
            title: l10n.aboutTabEncryptionSection0Item1Title,
            body: l10n.aboutTabEncryptionSection0Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.layers_outlined,
            title: l10n.aboutTabEncryptionSection0Item2Title,
            body: l10n.aboutTabEncryptionSection0Item2Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabEncryptionSection1Title,
        subtitle: l10n.aboutTabEncryptionSection1Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.phonelink_lock_outlined,
            title: l10n.aboutTabEncryptionSection1Item0Title,
            body: l10n.aboutTabEncryptionSection1Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.key_outlined,
            title: l10n.aboutTabEncryptionSection1Item1Title,
            body: l10n.aboutTabEncryptionSection1Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.fact_check_outlined,
            title: l10n.aboutTabEncryptionSection1Item2Title,
            body: l10n.aboutTabEncryptionSection1Item2Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabEncryptionSection2Title,
        subtitle: l10n.aboutTabEncryptionSection2Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.file_upload_outlined,
            title: l10n.aboutTabEncryptionSection2Item0Title,
            body: l10n.aboutTabEncryptionSection2Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.password_rounded,
            title: l10n.aboutTabEncryptionSection2Item1Title,
            body: l10n.aboutTabEncryptionSection2Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.security_outlined,
            title: l10n.aboutTabEncryptionSection2Item2Title,
            body: l10n.aboutTabEncryptionSection2Item2Body,
          ),
        ],
      ),
    ],
  ),
  AboutPageTabSpec(
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
      AboutPageSectionSpec(
        title: l10n.aboutTabSearchIndexSection0Title,
        subtitle: l10n.aboutTabSearchIndexSection0Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.search_rounded,
            title: l10n.aboutTabSearchIndexSection0Item0Title,
            body: l10n.aboutTabSearchIndexSection0Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.article_outlined,
            title: l10n.aboutTabSearchIndexSection0Item1Title,
            body: l10n.aboutTabSearchIndexSection0Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.lock_outline_rounded,
            title: l10n.aboutTabSearchIndexSection0Item2Title,
            body: l10n.aboutTabSearchIndexSection0Item2Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabSearchIndexSection1Title,
        subtitle: l10n.aboutTabSearchIndexSection1Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.manage_search_outlined,
            title: l10n.aboutTabSearchIndexSection1Item0Title,
            body: l10n.aboutTabSearchIndexSection1Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.save_outlined,
            title: l10n.aboutTabSearchIndexSection1Item1Title,
            body: l10n.aboutTabSearchIndexSection1Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.refresh_rounded,
            title: l10n.aboutTabSearchIndexSection1Item2Title,
            body: l10n.aboutTabSearchIndexSection1Item2Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabSearchIndexSection2Title,
        subtitle: l10n.aboutTabSearchIndexSection2Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.lock_open_rounded,
            title: l10n.aboutTabSearchIndexSection2Item0Title,
            body: l10n.aboutTabSearchIndexSection2Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.search_off_outlined,
            title: l10n.aboutTabSearchIndexSection2Item1Title,
            body: l10n.aboutTabSearchIndexSection2Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.storage_rounded,
            title: l10n.aboutTabSearchIndexSection2Item2Title,
            body: l10n.aboutTabSearchIndexSection2Item2Body,
          ),
        ],
      ),
    ],
  ),
  AboutPageTabSpec(
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
      AboutPageSectionSpec(
        title: l10n.aboutTabEditorSection0Title,
        subtitle: l10n.aboutTabEditorSection0Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.edit_outlined,
            title: l10n.aboutTabEditorSection0Item0Title,
            body: l10n.aboutTabEditorSection0Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.event_note_rounded,
            title: l10n.aboutTabEditorSection0Item1Title,
            body: l10n.aboutTabEditorSection0Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.local_offer_outlined,
            title: l10n.aboutTabEditorSection0Item2Title,
            body: l10n.aboutTabEditorSection0Item2Body,
          ),
          AboutPageItemSpec(
            icon: Icons.checklist_rounded,
            title: l10n.aboutTabEditorSection0Item3Title,
            body: l10n.aboutTabEditorSection0Item3Body,
          ),
          AboutPageItemSpec(
            icon: Icons.attach_file,
            title: l10n.aboutTabEditorSection0Item4Title,
            body: l10n.aboutTabEditorSection0Item4Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabEditorSection1Title,
        subtitle: l10n.aboutTabEditorSection1Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.save_as_outlined,
            title: l10n.aboutTabEditorSection1Item0Title,
            body: l10n.aboutTabEditorSection1Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.restore_rounded,
            title: l10n.aboutTabEditorSection1Item1Title,
            body: l10n.aboutTabEditorSection1Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.auto_delete_outlined,
            title: l10n.aboutTabEditorSection1Item2Title,
            body: l10n.aboutTabEditorSection1Item2Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabEditorSection2Title,
        subtitle: l10n.aboutTabEditorSection2Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.search_off_outlined,
            title: l10n.aboutTabEditorSection2Item0Title,
            body: l10n.aboutTabEditorSection2Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.archive_outlined,
            title: l10n.aboutTabEditorSection2Item1Title,
            body: l10n.aboutTabEditorSection2Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.pending_actions_outlined,
            title: l10n.aboutTabEditorSection2Item2Title,
            body: l10n.aboutTabEditorSection2Item2Body,
          ),
        ],
      ),
    ],
  ),
  AboutPageTabSpec(
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
      AboutPageSectionSpec(
        title: l10n.aboutTabPeopleSection0Title,
        subtitle: l10n.aboutTabPeopleSection0Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.badge_outlined,
            title: l10n.aboutTabPeopleSection0Item0Title,
            body: l10n.aboutTabPeopleSection0Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.handshake_outlined,
            title: l10n.aboutTabPeopleSection0Item1Title,
            body: l10n.aboutTabPeopleSection0Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.cake_outlined,
            title: l10n.aboutTabPeopleSection0Item2Title,
            body: l10n.aboutTabPeopleSection0Item2Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabPeopleSection1Title,
        subtitle: l10n.aboutTabPeopleSection1Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.auto_graph_outlined,
            title: l10n.aboutTabPeopleSection1Item0Title,
            body: l10n.aboutTabPeopleSection1Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.history_rounded,
            title: l10n.aboutTabPeopleSection1Item1Title,
            body: l10n.aboutTabPeopleSection1Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.alternate_email_rounded,
            title: l10n.aboutTabPeopleSection1Item2Title,
            body: l10n.aboutTabPeopleSection1Item2Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabPeopleSection2Title,
        subtitle: l10n.aboutTabPeopleSection2Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.edit_note_outlined,
            title: l10n.aboutTabPeopleSection2Item0Title,
            body: l10n.aboutTabPeopleSection2Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.person_remove_outlined,
            title: l10n.aboutTabPeopleSection2Item1Title,
            body: l10n.aboutTabPeopleSection2Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.rule_outlined,
            title: l10n.aboutTabPeopleSection2Item2Title,
            body: l10n.aboutTabPeopleSection2Item2Body,
          ),
        ],
      ),
    ],
  ),
  AboutPageTabSpec(
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
      AboutPageSectionSpec(
        title: l10n.aboutTabBackupRestoreSection0Title,
        subtitle: l10n.aboutTabBackupRestoreSection0Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.archive_outlined,
            title: l10n.aboutTabBackupRestoreSection0Item0Title,
            body: l10n.aboutTabBackupRestoreSection0Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.fact_check_outlined,
            title: l10n.aboutTabBackupRestoreSection0Item1Title,
            body: l10n.aboutTabBackupRestoreSection0Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.history_rounded,
            title: l10n.aboutTabBackupRestoreSection0Item2Title,
            body: l10n.aboutTabBackupRestoreSection0Item2Body(
              VaultBackupPolicy.retainCount,
            ),
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabBackupRestoreSection1Title,
        subtitle: l10n.aboutTabBackupRestoreSection1Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.swap_horiz_rounded,
            title: l10n.aboutTabBackupRestoreSection1Item0Title,
            body: l10n.aboutTabBackupRestoreSection1Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.refresh_rounded,
            title: l10n.aboutTabBackupRestoreSection1Item1Title,
            body: l10n.aboutTabBackupRestoreSection1Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.key_outlined,
            title: l10n.aboutTabBackupRestoreSection1Item2Title,
            body: l10n.aboutTabBackupRestoreSection1Item2Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabBackupRestoreSection2Title,
        subtitle: l10n.aboutTabBackupRestoreSection2Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.file_download_outlined,
            title: l10n.aboutTabBackupRestoreSection2Item0Title,
            body: l10n.aboutTabBackupRestoreSection2Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.file_upload_outlined,
            title: l10n.aboutTabBackupRestoreSection2Item1Title,
            body: l10n.aboutTabBackupRestoreSection2Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.cloud_off_rounded,
            title: l10n.aboutTabBackupRestoreSection2Item2Title,
            body: l10n.aboutTabBackupRestoreSection2Item2Body,
          ),
        ],
      ),
      AboutPageSectionSpec(
        title: l10n.aboutTabBackupRestoreSection3Title,
        subtitle: l10n.aboutTabBackupRestoreSection3Subtitle,
        items: <AboutPageItemSpec>[
          AboutPageItemSpec(
            icon: Icons.drafts_outlined,
            title: l10n.aboutTabBackupRestoreSection3Item0Title,
            body: l10n.aboutTabBackupRestoreSection3Item0Body,
          ),
          AboutPageItemSpec(
            icon: Icons.description_outlined,
            title: l10n.aboutTabBackupRestoreSection3Item1Title,
            body: l10n.aboutTabBackupRestoreSection3Item1Body,
          ),
          AboutPageItemSpec(
            icon: Icons.alt_route_rounded,
            title: l10n.aboutTabBackupRestoreSection3Item2Title,
            body: l10n.aboutTabBackupRestoreSection3Item2Body,
          ),
        ],
      ),
    ],
  ),
];
