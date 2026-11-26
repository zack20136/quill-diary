import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/application/session/session_timeout_policy.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';

typedef AboutTopicOverview = ({String title, String summary, IconData icon});
typedef AboutStep = ({String title, String body});

AboutTopicOverview aboutTopicOverview(
  AboutTopic topic,
  AppLocalizations l10n,
) => switch (topic) {
  AboutTopic.writing => (
    title: l10n.aboutWritingTitle,
    summary: l10n.aboutWritingSummary,
    icon: Icons.edit_note_rounded,
  ),
  AboutTopic.people => (
    title: l10n.aboutPeopleTitle,
    summary: l10n.aboutPeopleSummary,
    icon: Icons.people_alt_outlined,
  ),
  AboutTopic.ai => (
    title: l10n.aboutAiTitle,
    summary: l10n.aboutAiSummary,
    icon: Icons.auto_awesome_outlined,
  ),
  AboutTopic.privacy => (
    title: l10n.aboutPrivacyTitle,
    summary: l10n.aboutPrivacySummary,
    icon: Icons.lock_outline_rounded,
  ),
  AboutTopic.backup => (
    title: l10n.aboutBackupTitle,
    summary: l10n.aboutBackupSummary,
    icon: Icons.archive_outlined,
  ),
};

class AboutSection {
  const AboutSection(
    this.title, {
    required this.icon,
    this.paragraphs = const [],
    this.steps = const [],
    this.warning,
  });

  final String title;
  final IconData icon;
  final List<String> paragraphs;
  final List<AboutStep> steps;
  final String? warning;
}

List<AboutSection> aboutTopicSections(
  AboutTopic topic,
  AppLocalizations l10n,
  Duration sessionTimeout,
) => switch (topic) {
  AboutTopic.writing => [
    AboutSection(
      l10n.aboutWritingEditTitle,
      icon: Icons.edit_outlined,
      paragraphs: [
        l10n.aboutWritingEditBody(
          l10n.chatDiaryWriteDirectly,
          l10n.editorTooltipUploadImages,
          l10n.editorTooltipAddAttachment,
        ),
      ],
    ),
    AboutSection(
      l10n.aboutWritingSaveTitle,
      icon: Icons.save_outlined,
      paragraphs: [l10n.aboutWritingSaveBody(l10n.editorTooltipSave)],
    ),
    AboutSection(
      l10n.aboutWritingFindTitle,
      icon: Icons.search_rounded,
      paragraphs: [
        l10n.aboutWritingFindBody(l10n.homeNavTags, l10n.homeNavCalendar),
        l10n.aboutWritingFindRecent,
      ],
    ),
  ],
  AboutTopic.people => [
    AboutSection(
      l10n.aboutPeopleAddTitle,
      icon: Icons.person_add_alt_1_rounded,
      paragraphs: [
        l10n.aboutPeopleAddBody(l10n.homeNavPeople, l10n.peopleCreateAction),
        l10n.aboutPeopleMentionBody,
      ],
    ),
    AboutSection(
      l10n.aboutPeopleFindTitle,
      icon: Icons.manage_search_rounded,
      paragraphs: [l10n.aboutPeopleFindBody],
    ),
    AboutSection(
      l10n.aboutPeopleDeleteTitle,
      icon: Icons.person_remove_outlined,
      paragraphs: [l10n.aboutPeopleDeleteBody, l10n.aboutPeopleDeleteChats],
    ),
  ],
  AboutTopic.ai => [
    AboutSection(
      l10n.aboutAiSetupTitle,
      icon: Icons.tune_rounded,
      paragraphs: [
        l10n.aboutAiSetupBody(l10n.settingsPageTitle, l10n.aiOpenSettings),
      ],
    ),
    AboutSection(
      l10n.chatDiaryTitle,
      icon: Icons.chat_bubble_outline_rounded,
      paragraphs: [
        l10n.aboutAiChatStart(l10n.chatDiaryTitle),
        l10n.aboutAiChatBody(l10n.chatDiarySend, l10n.chatDiaryGenerateDiary),
        l10n.aboutAiChatPrivacy(l10n.aiHideSelection, l10n.aiPreviewRequest),
      ],
    ),
    AboutSection(
      l10n.organizationTitle,
      icon: Icons.edit_note_rounded,
      paragraphs: [
        l10n.aboutAiOrganizePrepare(
          l10n.organizationAiActions,
          l10n.organizationTitle,
          l10n.organizationStart,
        ),
        l10n.aboutAiOrganizeBody(l10n.organizationGenerate),
        l10n.aboutAiOrganizePrivacy(
          l10n.aiHideSelection,
          l10n.organizationApply,
        ),
      ],
    ),
    AboutSection(
      l10n.personaTitle,
      icon: Icons.person_outline_rounded,
      steps: [
        (
          title: l10n.aboutAiPersonaPrepareTitle,
          body: l10n.aboutAiPersonaBody(
            l10n.personaTitle,
            l10n.personaManage,
            l10n.personaGenerate,
          ),
        ),
        (title: l10n.personaTrial, body: l10n.aboutAiPersonaTrial),
        (
          title: l10n.aboutAiPersonaSaveTitle,
          body: l10n.aboutAiPersonaSave(
            l10n.personaSave,
            l10n.chatDiaryTitle,
            l10n.personaChooseCompanion,
          ),
        ),
      ],
    ),
  ],
  AboutTopic.privacy => [
    AboutSection(
      l10n.aboutPrivacyStorageTitle,
      icon: Icons.security_rounded,
      paragraphs: [
        l10n.aboutPrivacyStorageBody,
        l10n.aboutPrivacyStorageLimits,
      ],
    ),
    AboutSection(
      l10n.aboutPrivacyUnlockTitle,
      icon: Icons.lock_open_rounded,
      paragraphs: [
        l10n.settingsSessionTimeoutAboutBackgroundTimeoutBody(
          sessionBackgroundTimeoutLabel(sessionTimeout, l10n),
          l10n.personalizationNavButtonLabel,
          l10n.personalizationSessionTimeoutSectionTitle,
        ),
        l10n.aboutPrivacyUnlockBody(
          l10n.settingsUnlockMethodSectionTitle,
          l10n.settingsUnlockMethodSegmentDeviceLock,
          l10n.settingsUnlockMethodSegmentBiometric,
          l10n.commonActionVerifyAgain,
        ),
      ],
    ),
    AboutSection(
      l10n.aboutPrivacyKeyTitle,
      icon: Icons.key_rounded,
      paragraphs: [l10n.aboutPrivacyKeyBody],
    ),
  ],
  AboutTopic.backup => [
    AboutSection(
      l10n.aboutBackupMoveTitle,
      icon: Icons.swap_horiz_rounded,
      warning: l10n.settingsRestoreConfirmOverwriteHeadline,
      steps: [
        (
          title: l10n.aboutBackupMovePrepareTitle,
          body: l10n.aboutBackupMovePrepare(
            l10n.settingsPageTitle,
            l10n.settingsLocalBackupExportToExternalButton,
            l10n.settingsDriveBackupUploadButton,
          ),
        ),
        (
          title: l10n.aboutBackupMoveRestoreTitle,
          body: l10n.aboutBackupMoveRestore(
            l10n.firstLaunchTransferTitle,
            l10n.settingsLocalBackupImportFromExternalButton,
            l10n.settingsDriveBackupLinkButton,
            l10n.settingsDriveBackupRestoreButton,
          ),
        ),
        (
          title: l10n.aboutBackupMoveCheckTitle,
          body: l10n.aboutBackupMoveCheck,
        ),
      ],
    ),
    AboutSection(
      l10n.aboutBackupContentsTitle,
      icon: Icons.inventory_2_outlined,
      paragraphs: [
        l10n.aboutBackupContentsBody,
        l10n.aboutBackupExclusions,
        l10n.aboutBackupDriveBody,
      ],
    ),
    AboutSection(
      l10n.aboutBackupDocumentsTitle,
      icon: Icons.import_export_rounded,
      paragraphs: [
        l10n.aboutBackupImportBody(l10n.settingsImportExportImportButton),
        l10n.aboutBackupExportBody(l10n.settingsImportExportExportButton),
      ],
    ),
  ],
};
