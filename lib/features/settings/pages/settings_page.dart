import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_identifiers.dart';
import '../../../config/oauth_config.dart';
import '../../../app/router.dart';
import '../../../domain/recovery/recovery_metadata.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../infrastructure/drive/drive_backup_service.dart';
import '../../../infrastructure/security/app_unlock_mode.dart';
import '../../../infrastructure/storage/restore_precheck.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../infrastructure/storage/vault_archive_io.dart';
import '../../../infrastructure/storage/vault_transfer_service.dart';
import '../../../shared/presentation/display_format.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/utils/external_url.dart';
import '../../../shared/utils/user_facing_error.dart';
import '../../editor/providers/editor_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../session/providers/session_providers.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
import '../../session/state/unlock_result.dart';
import '../providers/settings_providers.dart';
import '../about_copy.dart';
import '../legal_disclosures.dart';
import '../portable_import_result_messages.dart';
import '../settings_copy.dart';
import '../unlock_mode_change.dart';
import '../vault_transfer_access.dart';
import '../../restore/post_restore_session.dart';
import '../../restore/restore_backup_flow.dart';
import '../backup/backup_pick_dialog.dart';
import '../backup/backup_pick_list_item.dart';
import '../widgets/drive_backup_section.dart';
import '../widgets/local_backup_section.dart';
import '../widgets/recovery_key_save_dialog.dart';
import '../widgets/settings_sections.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _recoveryKeyInputController = TextEditingController();
  bool _busy = false;
  String? _busyMessage;
  IndexRebuildReport? _lastIndexRebuildReport;

  @override
  void dispose() {
    _recoveryKeyInputController.dispose();
    super.dispose();
  }

  Future<void> _openLegalLink(String url) async {
    final bool opened = await launchExternalUrl(url);
    if (!mounted || opened) {
      return;
    }
    _showMessage(LegalDisclosures.externalLinkUnavailableMessage);
  }

  Widget _buildLegalSection(ColorScheme cs) {
    return SettingsSectionCard(
      icon: Icons.gavel_outlined,
      title: SettingsLegalCopy.sectionTitle,
      description: SettingsLegalCopy.sectionDescription,
      child: Column(
        children: <Widget>[
          _SettingsLegalRow(
            title: SettingsLegalCopy.sourceCodeTitle,
            onTap: () => unawaited(
              _openLegalLink(AppIdentifiers.sourceRepositoryUrl),
            ),
            colorScheme: cs,
          ),
          Divider(height: 1, color: PageStyle.outlineSide(cs).color),
          _SettingsLegalRow(
            title: SettingsLegalCopy.privacyPolicyTitle,
            onTap: () => unawaited(
              _openLegalLink(AppIdentifiers.privacyPolicyUrl),
            ),
            colorScheme: cs,
          ),
          Divider(height: 1, color: PageStyle.outlineSide(cs).color),
          _SettingsLegalRow(
            title: SettingsLegalCopy.thirdPartyNoticesTitle,
            onTap: () => unawaited(
              _openLegalLink(AppIdentifiers.thirdPartyNoticesUrl),
            ),
            colorScheme: cs,
          ),
          Divider(height: 1, color: PageStyle.outlineSide(cs).color),
          _SettingsLegalRow(
            title: SettingsLegalCopy.contactAuthorTitle,
            onTap: () => unawaited(
              _openLegalLink(AppIdentifiers.issuesUrl),
            ),
            colorScheme: cs,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStatusSection({
    required AsyncValue<AppSessionState> sessionAsync,
    required RecoveryMetadata? recoveryMetadata,
    required bool canVaultBackup,
    required AsyncValue<AppUnlockMode> unlockModeAsync,
  }) {
    final AppSessionState? sessionState = sessionAsync.asData?.value;
    final bool hasUnlockedSession =
        sessionState?.isUnlocked == true && sessionState?.session != null;
    return FutureBuilder<bool>(
      future: ref.read(vaultRepositoryProvider).hasTrustedDeviceAccess(),
      builder: (BuildContext context, AsyncSnapshot<bool> trustedSnapshot) {
        final AppUnlockMode mode = unlockModeAsync.asData?.value ?? AppUnlockMode.none;
        final bool hasTrustedDevice = trustedSnapshot.data ?? false;
        return SettingsSectionCard(
          icon: Icons.health_and_safety_outlined,
          title: SettingsSecurityOverviewCopy.sectionTitle,
          description: SettingsSecurityOverviewCopy.sectionDescription,
          child: SettingsSecurityOverview(
            hasRecoveryKey: recoveryMetadata != null,
            recoveryKeyHint: recoveryMetadata?.recoveryKeyHint,
            hasUnlockedSession: hasUnlockedSession,
            hasTrustedDevice: hasTrustedDevice,
            unlockModeLabel: mode.fullLabel,
            indexMessage: _indexStatusMessage(hasUnlockedSession),
            busy: _busy,
            onCreateRecoveryKey:
                recoveryMetadata == null ? () => _runAction(_createRecoveryKey) : null,
            onRotateRecoveryKey:
                recoveryMetadata != null && canVaultBackup
                    ? () => _runAction(_rotateRecoveryKey)
                    : null,
            onRebuildIndex:
                hasUnlockedSession ? () => _runAction(_rebuildIndex) : null,
            lockPanel: sessionState?.status == AppLockStatus.unlocked
                ? null
                : sessionAsync.when(
                    data: (AppSessionState sessionState) => SettingsStatusPanel(
                      sessionState: sessionState,
                      busy: _busy,
                      recoveryKeyInputController: _recoveryKeyInputController,
                      recoveryKeyHint: recoveryMetadata?.recoveryKeyHint,
                      bannerIcon: _sessionIcon(sessionState.status),
                      bannerMessage: _sessionSummary(sessionState),
                      bannerTone: _sessionTone(sessionState.status),
                      onUnlockWithRecovery:
                          sessionState.status == AppLockStatus.recoveryRequired
                              ? () => _runAction(() async {
                                    await ref
                                        .read(appSessionProvider.notifier)
                                        .unlockWithRecovery(
                                          _recoveryKeyInputController.text.trim(),
                                        );
                                    await refreshEntryIndexCaches(ref);
                                  })
                              : null,
                      onRetryTrustedUnlock:
                          (sessionState.status == AppLockStatus.locked &&
                                      sessionState.resumeAction == null) ||
                                  sessionState.status == AppLockStatus.unlocking
                              ? () => _runAction(_retryTrustedUnlock)
                              : null,
                      onCancelUnlock: sessionState.status == AppLockStatus.unlocking
                          ? () => _runAction(() async {
                                await ref.read(appSessionProvider.notifier).lock();
                              })
                          : null,
                    ),
                    loading: () => const SettingsSectionLoading(),
                    error: (Object error, StackTrace _) => SettingsInfoBanner(
                      icon: Icons.error_outline_rounded,
                      message: userFacingErrorMessage(error),
                      tone: SettingsBannerTone.error,
                    ),
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSupportedPlatform = ref.watch(supportedPlatformProvider);
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(effectiveAppSessionProvider);
    final AsyncValue<RecoveryMetadata?> recoveryMetadataAsync = ref.watch(recoveryMetadataProvider);
    final AsyncValue<AppUnlockMode> unlockModeAsync = ref.watch(unlockModeProvider);
    final AppSessionState? sessionState = sessionAsync.asData?.value;
    final RecoveryMetadata? recoveryMetadata = recoveryMetadataAsync.asData?.value;
    final bool hasUnlockedSession =
        sessionState?.isUnlocked == true && sessionState?.session != null;
    final bool hasRecoveryKey = recoveryMetadata != null;
    final VaultTransferAccess transferAccess = VaultTransferAccess.fromContext(
      hasUnlockedSession: hasUnlockedSession,
      hasRecoveryKey: hasRecoveryKey,
      lockStatus: sessionState?.status ?? AppLockStatus.uninitialized,
    );
    final bool isGoogleDriveConfigured =
        !Platform.isIOS || OAuthConfig.isIosGoogleDriveConfigured;

    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Text(SettingsCopy.pageTitle),
            const Spacer(),
            const _SettingsAppBarNavActions(),
          ],
        ),
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ColoredBox(
        color: pageBackground,
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              NotificationListener<OverscrollIndicatorNotification>(
                onNotification: (OverscrollIndicatorNotification notification) {
                  notification.disallowIndicator();
                  return false;
                },
                child: ColoredBox(
                  color: pageBackground,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: <Widget>[
                if (!isSupportedPlatform)
                  const SettingsSectionCard(
                    title: SettingsPlatformCopy.sectionTitle,
                    description: SettingsPlatformCopy.sectionDescription,
                    child: SettingsInfoBanner(
                      icon: Icons.phone_android_rounded,
                      message: kAndroidOnlyMessage,
                    ),
                  ),
                if (isSupportedPlatform) ...<Widget>[
                  _buildSecurityStatusSection(
                    sessionAsync: sessionAsync,
                    recoveryMetadata: recoveryMetadata,
                    canVaultBackup: transferAccess.canBackup,
                    unlockModeAsync: unlockModeAsync,
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    icon: Icons.phonelink_lock_outlined,
                    title: SettingsUnlockMethodCopy.sectionTitle,
                    description: SettingsUnlockMethodCopy.sectionDescription,
                    child: unlockModeAsync.when(
                      data: (AppUnlockMode unlockMode) => UnlockMethodSectionBody(
                        enabled: recoveryMetadataAsync.asData?.value != null,
                        changeAllowed: hasUnlockedSession,
                        busy: _busy,
                        unlockMode: unlockMode,
                        onModeSelected: (AppUnlockMode selected) => _runAction(
                          () => _applyUnlockMode(selected),
                        ),
                      ),
                      loading: () => const SettingsSectionLoading(),
                      error: (Object error, StackTrace _) => SettingsInfoBanner(
                        icon: Icons.error_outline_rounded,
                        message: userFacingErrorMessage(error),
                        tone: SettingsBannerTone.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    icon: Icons.swap_horiz_rounded,
                    title: SettingsImportExportCopy.sectionTitle,
                    description: transferAccess.canBackup
                        ? SettingsImportExportCopy.sectionDescriptionEnabled
                        : transferAccess.backupDisabledReason ??
                            VaultTransferCopy.needsUnlockForBackup,
                    child: SettingsActionGroup(
                      actions: <SettingsActionButton>[
                        SettingsActionButton(
                          label: SettingsImportExportCopy.importButton,
                          icon: Icons.file_download_outlined,
                          appearance: SettingsActionButtonAppearance.filled,
                          fullWidth: true,
                          onPressed: _busy || !transferAccess.canBackup
                              ? null
                              : () => _runAction(() async {
                                    final PortableImportResult? result = await ref
                                        .read(appSessionProvider.notifier)
                                        .runSensitiveTask((UnlockedVaultSession session) {
                                      return ref
                                          .read(vaultTransferServiceProvider)
                                          .importDocumentsWithPicker(session);
                                    });
                                    if (result == null) {
                                      return;
                                    }
                                    if (result.importedEntries == 0) {
                                      _showMessage(result.messageWhenNoEntriesImported());
                                      return;
                                    }
                                    await refreshEntryIndexCaches(ref);
                                    _showMessage(result.formatSuccessMessage());
                                  },
                                    progressMessage: SettingsImportExportCopy.importProgress,
                                  ),
                        ),
                        SettingsActionButton(
                          label: SettingsImportExportCopy.exportButton,
                          icon: Icons.file_upload_outlined,
                          appearance: SettingsActionButtonAppearance.tonal,
                          fullWidth: true,
                          onPressed: _busy || !transferAccess.canBackup
                              ? null
                              : () => _runAction(
                                    () async {
                                    final String? exportPath = await ref
                                        .read(appSessionProvider.notifier)
                                        .runSensitiveTask((UnlockedVaultSession session) {
                                      return ref
                                          .read(vaultTransferServiceProvider)
                                          .exportMarkdownToDirectory(session);
                                    });
                                    if (exportPath == null) {
                                      return;
                                    }
                                    _showMessage(
                                      SettingsImportExportCopy.exportSuccess(
                                        DisplayFormat.formatSavedFileNameForDisplay(
                                          exportPath,
                                        ),
                                      ),
                                    );
                                  },
                                    progressMessage: SettingsImportExportCopy.exportProgress,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  LocalBackupSection(
                    access: transferAccess,
                    busy: _busy,
                    onCreate: () => _runAction(_createLocalBackup),
                    onRestore: _runRestoreFromAppLocalBackup,
                    onExport: () => _runAction(_exportLocalBackup),
                    onImport: _runRestoreFromLocalBackup,
                  ),
                  const SizedBox(height: 16),
                  DriveBackupSection(
                    access: transferAccess,
                    isGoogleDriveConfigured: isGoogleDriveConfigured,
                    busy: _busy,
                    onLink: () => _runAction(
                      _linkGoogleDrive,
                      progressMessage: SettingsIndexCopy.linkDriveProgress,
                    ),
                    onSwitchAccount: () => _runAction(
                      _switchGoogleDrive,
                      progressMessage: SettingsIndexCopy.switchDriveAccountProgress,
                    ),
                    onDisconnect: _disconnectGoogleDrive,
                    onUpload: () => _runAction(_uploadDriveBackup),
                    onRestore: _runRestoreFromGoogleDrive,
                  ),
                ],
                const SizedBox(height: 16),
                _buildLegalSection(cs),
                    ],
                  ),
                ),
              ),
              if (_busy)
                SettingsBlockingProgressOverlay(
                  message: _busyMessage ?? SettingsCopy.progressDefault,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteBackup({
    required String title,
    required String body,
  }) async {
    if (!mounted) {
      return false;
    }
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(SettingsCopy.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(SettingsCopy.actionDelete),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<LocalBackupFile?> _pickLocalBackup(List<LocalBackupFile> backups) async {
    if (backups.isEmpty) {
      _showMessage(SettingsLocalBackupCopy.noBackups);
      return null;
    }
    if (!mounted) {
      return null;
    }

    final Map<String, LocalBackupFile> backupsById = <String, LocalBackupFile>{
      for (final LocalBackupFile backup in backups) backup.path: backup,
    };
    final BackupPickListItem? picked = await showBackupPickDialog(
      context: context,
      title: SettingsLocalBackupCopy.pickDialogTitle,
      emptyMessage: SettingsLocalBackupCopy.noBackups,
      deleteTooltip: SettingsLocalBackupCopy.deleteBackupTooltip,
      actionsDisabled: _busy,
      confirmDelete: (String fileName) => _confirmDeleteBackup(
        title: SettingsLocalBackupCopy.deleteConfirmTitle,
        body: SettingsLocalBackupCopy.deleteConfirmBody(fileName),
      ),
      items: backups
          .map(
            (LocalBackupFile backup) => BackupPickListItem(
              id: backup.path,
              createdAtLabel: _formatLocalBackupTime(backup),
              fileName: backup.name,
              sizeLabel: _formatBytes(backup.sizeBytes),
              onDelete: () async {
                await ref.read(vaultTransferServiceProvider).deleteAppLocalBackup(backup);
                _showSuccess(SettingsLocalBackupCopy.deleteBackupSuccess(backup.name));
              },
            ),
          )
          .toList(),
    );
    return picked == null ? null : backupsById[picked.id];
  }

  Future<DriveBackupFile?> _pickDriveBackup(List<DriveBackupFile> backups) async {
    if (backups.isEmpty) {
      _showMessage(SettingsDriveBackupCopy.noBackups);
      return null;
    }
    if (!mounted) {
      return null;
    }

    final Map<String, DriveBackupFile> backupsById = <String, DriveBackupFile>{
      for (final DriveBackupFile backup in backups) backup.id: backup,
    };
    final BackupPickListItem? picked = await showBackupPickDialog(
      context: context,
      title: SettingsDriveBackupCopy.pickDialogTitle,
      emptyMessage: SettingsDriveBackupCopy.noBackups,
      deleteTooltip: SettingsDriveBackupCopy.deleteBackupTooltip,
      actionsDisabled: _busy,
      confirmDelete: (String fileName) => _confirmDeleteBackup(
        title: SettingsDriveBackupCopy.deleteConfirmTitle,
        body: SettingsDriveBackupCopy.deleteConfirmBody(fileName),
      ),
      items: backups
          .map(
            (DriveBackupFile backup) => BackupPickListItem(
              id: backup.id,
              createdAtLabel: _formatDriveBackupTime(backup.createdAt),
              fileName: backup.name,
              sizeLabel: backup.sizeBytes == null
                  ? null
                  : _formatBytes(backup.sizeBytes!),
              onDelete: () async {
                await ref.read(vaultTransferServiceProvider).deleteDriveBackup(backup);
                _showSuccess(SettingsDriveBackupCopy.deleteBackupSuccess(backup.name));
              },
            ),
          )
          .toList(),
    );
    return picked == null ? null : backupsById[picked.id];
  }

  String _indexStatusMessage(bool hasUnlockedSession) {
    final IndexRebuildReport? report = _lastIndexRebuildReport;
    if (report != null) {
      return SettingsIndexCopy.rebuildCompleted(
        report.entryCount,
        DisplayFormat.formatDateTimeZh(report.finishedAt),
      );
    }
    return hasUnlockedSession
        ? SettingsIndexCopy.readyMessage
        : SettingsIndexCopy.lockedMessage;
  }

  Future<void> _createRecoveryKey() async {
    final RecoverySetupResult result =
        await ref.read(vaultRepositoryProvider).setupRecoveryKey();
    ref.read(appSessionProvider.notifier).activateSession(
          result.session,
          message: kRecoverySetupSuccessMessage,
        );
    ref.invalidate(recoveryMetadataProvider);
    await refreshEntryIndexCaches(ref);
    if (!mounted) {
      return;
    }
    await showRecoveryKeySaveDialog(
      context,
      title: SettingsRecoveryKeyCopy.saveDialogTitle,
      recoveryKey: result.recoveryKey,
    );
  }

  Future<void> _createLocalBackup() async {
    final BackupPersistResult result = await ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((_) {
      return ref.read(vaultTransferServiceProvider).saveBackupToAppLocal();
    });
    _showBackupPersistResult(
      result,
      onSuccess: SettingsLocalBackupCopy.backupSuccessInApp,
    );
  }

  Future<void> _exportLocalBackup() async {
    final BackupPersistResult result = await ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((_) {
      return ref.read(vaultTransferServiceProvider).saveBackupToExternalDirectory();
    });
    _showBackupPersistResult(
      result,
      onSuccess: SettingsLocalBackupCopy.backupExportSuccess,
    );
  }

  Future<void> _uploadDriveBackup() async {
    final BackupPersistResult result = await ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((_) {
      return ref.read(vaultTransferServiceProvider).uploadBackupToDrive();
    });
    _showBackupPersistResult(
      result,
      onSuccess: SettingsDriveBackupCopy.uploadSuccess,
      inspectFailedMessage: SettingsDriveBackupCopy.backupInspectFailed,
    );
  }

  Future<void> _runRestoreFromAppLocalBackup() async {
    try {
      final List<LocalBackupFile> backups =
          await ref.read(vaultTransferServiceProvider).listAppLocalBackups();
      final LocalBackupFile? backup = await _pickLocalBackup(backups);
      if (backup == null) {
        return;
      }
      await _restoreBackupFileWithFlow(File(backup.path));
    } catch (error) {
      _showError(userFacingErrorMessage(error));
    }
  }

  Future<void> _rebuildIndex() async {
    final IndexRebuildReport report = await ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((UnlockedVaultSession session) {
      return ref.read(vaultRepositoryProvider).rebuildIndexWithReport(session);
    });
    ref.read(entryIndexRevisionProvider.notifier).bump();
    ref.invalidate(recoveryMetadataProvider);
    if (mounted) {
      setState(() => _lastIndexRebuildReport = report);
    }
    _showMessage(SettingsIndexCopy.rebuildSuccess(
      report.entryCount,
      DisplayFormat.formatDurationMs(report.duration.inMilliseconds),
    ));
  }

  String _formatDriveBackupTime(DateTime? value) {
    if (value == null) {
      return SettingsDriveBackupCopy.unknownCreatedTime;
    }
    return DisplayFormat.formatDateTimeZh(value);
  }

  String _formatLocalBackupTime(LocalBackupFile backup) {
    return DisplayFormat.formatDateTimeZh(backup.createdAt);
  }

  String _formatBytes(int bytes) => DisplayFormat.formatBytesForDisplay(bytes);

  Future<void> _runRestoreFromLocalBackup() async {
    final File? backupFile =
        await ref.read(vaultTransferServiceProvider).pickLocalBackupFile();
    if (backupFile == null) {
      return;
    }
    await _restoreBackupFileWithFlow(backupFile);
  }

  Future<void> _runRestoreFromGoogleDrive() async {
    File? tempBackup;
    String? driveBackupName;
    try {
      final List<DriveBackupFile> backups =
          await ref.read(vaultTransferServiceProvider).listDriveBackups();
      final DriveBackupFile? backup = await _pickDriveBackup(backups);
      if (backup == null) {
        return;
      }
      driveBackupName = backup.name;
      await _runAction(() async {
        tempBackup = await ref
            .read(vaultTransferServiceProvider)
            .downloadDriveBackupToTempFile(backup);
      }, progressMessage: SettingsDriveBackupCopy.downloadProgress);
      if (tempBackup == null) {
        return;
      }
      await _restoreBackupFileWithFlow(
        tempBackup!,
        driveBackupName: driveBackupName,
      );
    } catch (error) {
      _showError(userFacingErrorMessage(error));
    } finally {
      if (tempBackup != null && tempBackup!.existsSync()) {
        await tempBackup!.delete();
      }
    }
  }

  Future<void> _linkGoogleDrive() async {
    final DriveConnectionState connectionState =
        await ref.read(vaultTransferServiceProvider).linkGoogleDrive();
    ref.invalidate(settingsDriveConnectionProvider);
    await ref.read(settingsDriveConnectionProvider.future);
    _showSuccess(SettingsDriveBackupCopy.linkSuccess(connectionState.accountLabel));
  }

  Future<void> _switchGoogleDrive() async {
    final DriveConnectionState connectionState =
        await ref.read(vaultTransferServiceProvider).switchGoogleDrive();
    ref.invalidate(settingsDriveConnectionProvider);
    await ref.read(settingsDriveConnectionProvider.future);
    _showSuccess(
      SettingsDriveBackupCopy.switchAccountSuccess(connectionState.accountLabel),
    );
  }

  Future<void> _disconnectGoogleDrive() async {
    if (!mounted) {
      return;
    }
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text(SettingsDriveBackupCopy.disconnectConfirmTitle),
            content: const Text(SettingsDriveBackupCopy.disconnectConfirmBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(SettingsCopy.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(SettingsDriveBackupCopy.disconnectButton),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await _runAction(
      () => ref.read(vaultTransferServiceProvider).disconnectGoogleDrive(),
      progressMessage: SettingsIndexCopy.disconnectDriveProgress,
    );
    ref.invalidate(settingsDriveConnectionProvider);
    await ref.read(settingsDriveConnectionProvider.future);
    _showSuccess(SettingsDriveBackupCopy.disconnectSuccess);
  }

  Future<void> _restoreBackupFileWithFlow(
    File backupFile, {
    String? driveBackupName,
  }) async {
    try {
      final RestorePrecheck precheck =
          await ref.read(vaultTransferServiceProvider).precheckRestore(backupFile);
      await _runAction(
        () => RestoreBackupFlow(ref).run(
          context: context,
          backupFile: backupFile,
          precheck: precheck,
          driveBackupName: driveBackupName,
          confirm: _confirmRestore,
          onComplete: ({
            String? backupRecoveryKey,
            required RestorePrecheck precheck,
            UnlockedVaultSession? priorSession,
          }) =>
              _finishRestoreAfterSuccess(
            backupRecoveryKey: backupRecoveryKey,
            precheck: precheck,
            priorSession: priorSession,
            driveBackupName: driveBackupName,
          ),
        ),
        progressMessage: kRestoreInProgressMessage,
      );
    } on StateError catch (error) {
      _showError(userFacingErrorMessage(error));
    }
  }

  Future<bool> _confirmRestore(
    RestorePrecheck precheck, {
    String? driveBackupName,
  }) async {
    final List<String> bullets = buildRestoreConfirmBulletPoints(precheck);
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(
                driveBackupName == null
                    ? SettingsRestoreDialogCopy.confirmLocalTitle
                    : SettingsRestoreDialogCopy.confirmDriveTitle,
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (driveBackupName != null) ...<Widget>[
                      Text(SettingsRestoreDialogCopy.driveFileLine(driveBackupName)),
                      const SizedBox(height: 12),
                    ],
                    for (final String bullet in bullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text('• '),
                            Expanded(child: Text(bullet)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(SettingsCopy.actionCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text(SettingsCopy.actionConfirm),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _finishRestoreAfterSuccess({
    String? backupRecoveryKey,
    required RestorePrecheck precheck,
    UnlockedVaultSession? priorSession,
    String? driveBackupName,
  }) async {
    final AppSessionState sessionState = await finishRestoreSession(
      ref,
      precheck: precheck,
      backupRecoveryKey: backupRecoveryKey,
      priorSession: priorSession,
    );

    if (!mounted) {
      return;
    }

    final String? trimmedKey = backupRecoveryKey?.trim();
    if (trimmedKey != null &&
        trimmedKey.isNotEmpty &&
        sessionState.status != AppLockStatus.unlocked) {
      _showError(
        sessionState.message ?? VaultTransferCopy.restoreUnlockFailed,
      );
      return;
    }

    context.go(AppRouter.homeRoute);
    _showSuccess(
      driveAwarePostRestoreSnackBarMessage(
        status: sessionState.status,
        sessionMessage: sessionState.message,
        driveBackupName: driveBackupName,
      ),
    );
  }

  Future<void> _retryTrustedUnlock() async {
    final UnlockOutcome outcome = await ref.read(appSessionProvider.notifier).unlock();
    if (outcome == UnlockOutcome.success) {
      await refreshEntryIndexCaches(ref);
    }
  }

  Future<void> _applyUnlockMode(AppUnlockMode mode) async {
    final UnlockModeChangeOutcome outcome = await applyUnlockModeChange(
      ref: ref,
      mode: mode,
    );
    if (outcome is UnlockModeChangeMessage) {
      _showMessage(outcome.message);
    }
  }

  Future<void> _rotateRecoveryKey() async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text(SettingsRecoveryKeyCopy.rotateDialogTitle),
              content: const Text(SettingsRecoveryKeyCopy.rotateDialogBody),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(SettingsCopy.actionCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text(SettingsCopy.actionUpdate),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await ref.read(appSessionProvider.notifier).runSensitiveTask((UnlockedVaultSession session) async {
      final RecoverySetupResult result =
          await ref.read(vaultRepositoryProvider).rotateRecoveryKey(session);
      ref.read(appSessionProvider.notifier).activateSession(
            result.session,
            message: kRecoveryKeyRotatedMessage,
          );
      ref.invalidate(recoveryMetadataProvider);
      await refreshEntryIndexCaches(ref);
      if (!mounted) {
        return;
      }
      await showRecoveryKeySaveDialog(
        context,
        title: SettingsRecoveryKeyCopy.saveNewDialogTitle,
        recoveryKey: result.recoveryKey,
      );
    });
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String? progressMessage,
  }) async {
    setState(() {
      _busy = true;
      _busyMessage = progressMessage;
    });
    try {
      await action();
    } catch (error) {
      _showError(userFacingErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  void _showBackupPersistResult(
    BackupPersistResult result, {
    required String Function(String savedPath) onSuccess,
    String Function(String message)? inspectFailedMessage,
  }) {
    switch (result.status) {
      case BackupPersistStatus.success:
        final String? savedPath = result.savedPath;
        if (savedPath != null) {
          _showSuccess(
            onSuccess(DisplayFormat.formatSavedFileNameForDisplay(savedPath)),
          );
        }
        return;
      case BackupPersistStatus.inspectFailed:
        final String Function(String message) formatInspectFailed =
            inspectFailedMessage ?? SettingsLocalBackupCopy.backupInspectFailed;
        _showError(formatInspectFailed(result.message));
        return;
      case BackupPersistStatus.cancelled:
        return;
    }
  }

  void _showMessage(String message) {
    _showFeedback(message);
  }

  void _showSuccess(String message) {
    _showFeedback(message, isSuccess: true);
  }

  void _showError(String message) {
    _showFeedback(message, isError: true);
  }

  void _showFeedback(
    String message, {
    bool isSuccess = false,
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: isError
              ? TextStyle(color: colorScheme.onError)
              : isSuccess
                  ? TextStyle(color: colorScheme.onPrimaryContainer)
                  : null,
        ),
        backgroundColor: isError
            ? colorScheme.error
            : isSuccess
                ? colorScheme.primaryContainer
                : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 設定頁 AppBar 右側按鈕列（介紹、贊助）。
class _SettingsAppBarNavActions extends StatelessWidget {
  const _SettingsAppBarNavActions();

  static const double _gap = 8;
  static const double _padding = 8;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: _padding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _SettingsAppBarNavButton(
            label: SettingsAboutCopy.pageTitle,
            onPressed: () => unawaited(context.push(AppRouter.aboutRoute)),
          ),
          const SizedBox(width: _gap),
          _SettingsAppBarNavButton(
            label: SettingsSupportCopy.navButtonLabel,
            onPressed: () => unawaited(context.push(AppRouter.supportRoute)),
          ),
        ],
      ),
    );
  }
}

class _SettingsAppBarNavButton extends StatelessWidget {
  const _SettingsAppBarNavButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Material(
      color: Color.alphaBlend(
        cs.surfaceContainerHigh.withValues(alpha: 0.72),
        cs.surface,
      ),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsLegalRow extends StatelessWidget {
  const _SettingsLegalRow({
    required this.title,
    required this.onTap,
    required this.colorScheme,
  });

  final String title;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sessionSummary(AppSessionState sessionState) {
  final String? message = sessionState.message;
  return switch (sessionState.status) {
    AppLockStatus.uninitialized => message ?? SettingsSecurityLockCopy.statusPreparing,
    AppLockStatus.unlocking => message ?? kTrustedUnlockInProgressMessage,
    AppLockStatus.unlocked => message ?? SettingsSecurityLockCopy.statusUnlocked,
    AppLockStatus.locked => message ?? kLockedRetryVerificationMessage,
    AppLockStatus.recoveryRequired =>
        message ?? kRecoveryRequiredAfterRestoreMessage,
    AppLockStatus.fatalError => message ?? SettingsSecurityLockCopy.statusFatalError,
  };
}

IconData _sessionIcon(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.uninitialized => Icons.hourglass_top_rounded,
    AppLockStatus.unlocking => Icons.sync_rounded,
    AppLockStatus.unlocked => Icons.lock_open_rounded,
    AppLockStatus.locked => Icons.lock_outline_rounded,
    AppLockStatus.recoveryRequired => Icons.key_outlined,
    AppLockStatus.fatalError => Icons.error_outline_rounded,
  };
}

SettingsBannerTone _sessionTone(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.uninitialized => SettingsBannerTone.neutral,
    AppLockStatus.unlocking => SettingsBannerTone.neutral,
    AppLockStatus.recoveryRequired => SettingsBannerTone.warning,
    AppLockStatus.fatalError => SettingsBannerTone.error,
    _ => SettingsBannerTone.neutral,
  };
}
