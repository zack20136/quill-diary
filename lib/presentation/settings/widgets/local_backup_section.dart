import 'package:flutter/material.dart';

import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/presentation/settings/settings_messages.dart';
import '../vault_transfer_access.dart';
import 'settings_sections.dart';

class LocalBackupSection extends StatelessWidget {
  const LocalBackupSection({
    required this.access,
    required this.busy,
    required this.onCreate,
    required this.onRestore,
    required this.onExport,
    required this.onImport,
    super.key,
  });

  final VaultTransferAccess access;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onRestore;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? lockedBannerMessage = localBackupLockedBannerMessage(
      l10n,
      access,
    );

    return SettingsSectionCard(
      icon: Icons.storage_rounded,
      title: l10n.settingsLocalBackupSectionTitle,
      description: localBackupSectionDescription(l10n, access),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SettingsActionGroup(
            actions: <SettingsActionButton>[
              SettingsActionButton(
                label: l10n.settingsLocalBackupCreateButton,
                icon: Icons.archive_outlined,
                appearance: SettingsActionButtonAppearance.filled,
                fullWidth: true,
                onPressed: busy || !access.canBackup ? null : onCreate,
              ),
              SettingsActionButton(
                label: l10n.settingsLocalBackupRestoreButton,
                icon: Icons.restore_rounded,
                appearance: SettingsActionButtonAppearance.tonal,
                fullWidth: true,
                onPressed: busy || !access.canRestore ? null : onRestore,
              ),
              SettingsActionButton(
                label: l10n.settingsLocalBackupExportToExternalButton,
                icon: Icons.file_upload_outlined,
                appearance: SettingsActionButtonAppearance.filled,
                fullWidth: true,
                onPressed: busy || !access.canBackup ? null : onExport,
              ),
              SettingsActionButton(
                label: l10n.settingsLocalBackupImportFromExternalButton,
                icon: Icons.file_download_outlined,
                appearance: SettingsActionButtonAppearance.tonal,
                fullWidth: true,
                onPressed: busy || !access.canRestore ? null : onImport,
              ),
            ],
          ),
          if (lockedBannerMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            AppFeedbackBanner(
              icon: Icons.lock_outline_rounded,
              message: lockedBannerMessage,
              tone: AppFeedbackTone.warning,
            ),
          ],
        ],
      ),
    );
  }
}
