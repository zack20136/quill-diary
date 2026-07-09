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
      l10n.aboutTabIntroChip0,
      l10n.aboutTabIntroChip1,
      l10n.aboutTabIntroChip2,
      l10n.aboutTabIntroChip3,
      l10n.aboutTabIntroChip4,
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
      l10n.aboutTabUnlockSessionChip0,
      l10n.aboutTabUnlockSessionChip1,
      l10n.aboutTabUnlockSessionChip2,
      l10n.aboutTabUnlockSessionChip3,
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
      l10n.aboutTabEncryptionChip0,
      l10n.aboutTabEncryptionChip1,
      l10n.aboutTabEncryptionChip2,
      l10n.aboutTabEncryptionChip3,
      l10n.aboutTabEncryptionChip4,
      l10n.aboutTabEncryptionChip5,
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
      l10n.aboutTabSearchIndexChip0,
      l10n.aboutTabSearchIndexChip1,
      l10n.aboutTabSearchIndexChip2,
      l10n.aboutTabSearchIndexChip3,
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
      l10n.aboutTabEditorChip0,
      l10n.aboutTabEditorChip1,
      l10n.aboutTabEditorChip2,
      l10n.aboutTabEditorChip3,
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
    label: l10n.aboutTabBackupRestoreLabel,
    heroIcon: Icons.storage_rounded,
    heroTitle: l10n.aboutTabBackupRestoreHeroTitle,
    heroBody: l10n.aboutTabBackupRestoreHeroBody,
    chips: <String>[
      l10n.aboutTabBackupRestoreChip0,
      l10n.aboutTabBackupRestoreChip1,
      l10n.aboutTabBackupRestoreChip2,
      l10n.aboutTabBackupRestoreChip3,
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
