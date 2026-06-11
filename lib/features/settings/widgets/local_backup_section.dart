import 'package:flutter/material.dart';

import '../settings_copy.dart';
import 'settings_sections.dart';

/// 設定頁的本機備份與還原區塊。
class LocalBackupSection extends StatelessWidget {
  const LocalBackupSection({
    required this.busy,
    required this.canSensitiveVaultTransfer,
    required this.disabledReason,
    required this.onCreate,
    required this.onRestore,
    required this.onExport,
    required this.onImport,
    super.key,
  });

  final bool busy;
  final bool canSensitiveVaultTransfer;
  final String disabledReason;
  final VoidCallback onCreate;
  final VoidCallback onRestore;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      icon: Icons.storage_rounded,
      title: SettingsLocalBackupCopy.sectionTitle,
      description: canSensitiveVaultTransfer
          ? SettingsLocalBackupCopy.sectionDescriptionEnabled
          : disabledReason,
      child: SettingsActionGroup(
        actions: <SettingsActionButton>[
          SettingsActionButton(
            label: SettingsLocalBackupCopy.createButton,
            icon: Icons.archive_outlined,
            appearance: SettingsActionButtonAppearance.filled,
            fullWidth: true,
            onPressed: busy || !canSensitiveVaultTransfer ? null : onCreate,
          ),
          SettingsActionButton(
            label: SettingsLocalBackupCopy.restoreButton,
            icon: Icons.restore_rounded,
            appearance: SettingsActionButtonAppearance.tonal,
            fullWidth: true,
            onPressed: busy || !canSensitiveVaultTransfer ? null : onRestore,
          ),
          SettingsActionButton(
            label: SettingsLocalBackupCopy.exportToExternalButton,
            icon: Icons.file_upload_outlined,
            appearance: SettingsActionButtonAppearance.outlined,
            fullWidth: true,
            onPressed: busy || !canSensitiveVaultTransfer ? null : onExport,
          ),
          SettingsActionButton(
            label: SettingsLocalBackupCopy.importFromExternalButton,
            icon: Icons.file_download_outlined,
            appearance: SettingsActionButtonAppearance.outlined,
            fullWidth: true,
            onPressed: busy || !canSensitiveVaultTransfer ? null : onImport,
          ),
        ],
      ),
    );
  }
}
