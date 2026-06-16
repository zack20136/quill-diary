import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../settings_messages.dart';
import '../vault_transfer_access.dart';
import 'settings_sections.dart';

/// 設定頁的本機備份與還原區塊。
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
    return SettingsSectionCard(
      icon: Icons.storage_rounded,
      title: l10n.settingsLocalBackupSectionTitle,
      description: access.canBackup
          ? settingsLocalBackupSectionDescriptionEnabled(l10n)
          : l10n.vaultTransferLocalSectionDescriptionBackupLocked,
      child: SettingsActionGroup(
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
            onPressed: busy || !access.canBackup ? null : onRestore,
          ),
          SettingsActionButton(
            label: l10n.settingsLocalBackupExportToExternalButton,
            icon: Icons.file_upload_outlined,
            appearance: SettingsActionButtonAppearance.outlined,
            fullWidth: true,
            onPressed: busy || !access.canBackup ? null : onExport,
          ),
          SettingsActionButton(
            label: l10n.settingsLocalBackupImportFromExternalButton,
            icon: Icons.file_download_outlined,
            appearance: SettingsActionButtonAppearance.outlined,
            fullWidth: true,
            onPressed: busy || !access.canRestore ? null : onImport,
          ),
        ],
      ),
    );
  }
}
