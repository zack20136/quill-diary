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
import '../../../infrastructure/storage/backup_task_progress.dart';
import '../../../l10n/l10n.dart';
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
import '../providers/personalization_providers.dart';
import '../portable_import_result_messages.dart';
import '../settings_messages.dart';
import '../unlock_mode_change.dart';
import '../vault_transfer_access.dart';
import '../../restore/restore_backup_flow.dart';
import '../../restore/restore_prepared_context.dart';
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
  final TextEditingController _recoveryKeyInputController =
      TextEditingController();
  bool _busy = false;
  String? _busyMessage;
  double? _busyProgress;
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
    _showMessage(context.l10n.legalExternalLinkUnavailableMessage);
  }

  Widget _buildLegalSection(BuildContext context, ColorScheme cs) {
    final AppLocalizations l10n = context.l10n;
    return SettingsSectionCard(
      icon: Icons.gavel_outlined,
      title: l10n.settingsLegalSectionTitle,
      description: l10n.settingsLegalSectionDescription,
      child: Column(
        children: <Widget>[
          _SettingsLegalRow(
            title: l10n.settingsLegalSourceCodeTitle,
            onTap: () =>
                unawaited(_openLegalLink(AppIdentifiers.sourceRepositoryUrl)),
            colorScheme: cs,
          ),
          Divider(height: 1, color: PageStyle.outlineSide(cs).color),
          _SettingsLegalRow(
            title: l10n.settingsLegalPrivacyPolicyTitle,
            onTap: () =>
                unawaited(_openLegalLink(AppIdentifiers.privacyPolicyUrl)),
            colorScheme: cs,
          ),
          Divider(height: 1, color: PageStyle.outlineSide(cs).color),
          _SettingsLegalRow(
            title: l10n.settingsLegalThirdPartyNoticesTitle,
            onTap: () =>
                unawaited(_openLegalLink(AppIdentifiers.thirdPartyNoticesUrl)),
            colorScheme: cs,
          ),
          Divider(height: 1, color: PageStyle.outlineSide(cs).color),
          _SettingsLegalRow(
            title: l10n.settingsLegalContactAuthorTitle,
            onTap: () => unawaited(_openLegalLink(AppIdentifiers.issuesUrl)),
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
        final AppUnlockMode mode =
            unlockModeAsync.asData?.value ?? AppUnlockMode.none;
        final bool hasTrustedDevice = trustedSnapshot.data ?? false;
        final AppLocalizations l10n = context.l10n;
        return SettingsSectionCard(
          icon: Icons.health_and_safety_outlined,
          title: l10n.settingsSecurityOverviewSectionTitle,
          description: l10n.settingsSecurityOverviewSectionDescription,
          child: SettingsSecurityOverview(
            hasRecoveryKey: recoveryMetadata != null,
            recoveryKeyHint: recoveryMetadata?.recoveryKeyHint,
            hasUnlockedSession: hasUnlockedSession,
            hasTrustedDevice: hasTrustedDevice,
            unlockModeLabel: mode.fullLabel(l10n),
            indexMessage: _indexStatusMessage(l10n, hasUnlockedSession),
            busy: _busy,
            onCreateRecoveryKey: recoveryMetadata == null
                ? () => _runBusy(_createRecoveryKey)
                : null,
            onRotateRecoveryKey: recoveryMetadata != null && canVaultBackup
                ? () => _runBusy(_rotateRecoveryKey)
                : null,
            onRebuildIndex: hasUnlockedSession
                ? () => _runBusy(_rebuildIndex)
                : null,
            lockPanel: sessionState?.status == AppLockStatus.unlocked
                ? null
                : sessionAsync.when(
                    data: (AppSessionState sessionState) => SettingsStatusPanel(
                      sessionState: sessionState,
                      busy: _busy,
                      recoveryKeyInputController: _recoveryKeyInputController,
                      recoveryKeyHint: recoveryMetadata?.recoveryKeyHint,
                      bannerIcon: _sessionIcon(sessionState.status),
                      bannerMessage: _sessionSummary(l10n, sessionState),
                      bannerTone: _sessionTone(sessionState.status),
                      onUnlockWithRecovery:
                          sessionState.status == AppLockStatus.recoveryRequired
                          ? () => _runBusy(() async {
                              await ref
                                  .read(appSessionProvider.notifier)
                                  .unlockWithRecovery(
                                    _recoveryKeyInputController.text.trim(),
                                  );
                              await refreshEntryIndexCaches(ref);
                            })
                          : null,
                      onRetryTrustedUnlock:
                          sessionState.status == AppLockStatus.locked ||
                              sessionState.status == AppLockStatus.unlocking
                          ? () => _runBusy(_retryTrustedUnlock)
                          : null,
                      onCancelUnlock:
                          sessionState.status == AppLockStatus.unlocking
                          ? () => _runBusy(() async {
                              await ref
                                  .read(appSessionProvider.notifier)
                                  .lock();
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
    final AppLocalizations l10n = context.l10n;
    final bool isSupportedPlatform = ref.watch(supportedPlatformProvider);
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(
      effectiveAppSessionProvider,
    );
    final AsyncValue<RecoveryMetadata?> recoveryMetadataAsync = ref.watch(
      recoveryMetadataProvider,
    );
    final AsyncValue<AppUnlockMode> unlockModeAsync = ref.watch(
      unlockModeProvider,
    );
    final AppSessionState? sessionState = sessionAsync.asData?.value;
    final RecoveryMetadata? recoveryMetadata =
        recoveryMetadataAsync.asData?.value;
    final bool hasUnlockedSession =
        sessionState?.isUnlocked == true && sessionState?.session != null;
    final bool hasRecoveryKey = recoveryMetadata != null;
    final VaultTransferAccess transferAccess = VaultTransferAccess.fromContext(
      l10n: context.l10n,
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
        title: Text(l10n.settingsPageTitle),
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
                      const _SettingsTopNavSection(),
                      const SizedBox(height: 16),
                      if (!isSupportedPlatform)
                        SettingsSectionCard(
                          title: l10n.settingsPlatformSectionTitle,
                          description: l10n.settingsPlatformSectionDescription,
                          child: SettingsInfoBanner(
                            icon: Icons.phone_android_rounded,
                            message: sessionAndroidOnlyMessage(l10n),
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
                          title: l10n.settingsUnlockMethodSectionTitle,
                          description: settingsUnlockMethodSectionDescription(
                            l10n,
                            watchPersonalizationPreferences(ref).sessionTimeout,
                          ),
                          child: unlockModeAsync.when(
                            data: (AppUnlockMode unlockMode) =>
                                UnlockMethodSectionBody(
                                  enabled:
                                      recoveryMetadataAsync.asData?.value !=
                                      null,
                                  changeAllowed: hasUnlockedSession,
                                  busy: _busy,
                                  unlockMode: unlockMode,
                                  onModeSelected: (AppUnlockMode selected) =>
                                      _runBusy(
                                        () => _applyUnlockMode(selected),
                                      ),
                                ),
                            loading: () => const SettingsSectionLoading(),
                            error: (Object error, StackTrace _) =>
                                SettingsInfoBanner(
                                  icon: Icons.error_outline_rounded,
                                  message: userFacingErrorMessage(error),
                                  tone: SettingsBannerTone.error,
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SettingsSectionCard(
                          icon: Icons.swap_horiz_rounded,
                          title: l10n.settingsImportExportSectionTitle,
                          description: transferAccess.canBackup
                              ? l10n.settingsImportExportSectionDescriptionEnabled
                              : transferAccess.backupDisabledReason ??
                                    l10n.vaultTransferNeedsUnlockForBackup,
                          child: SettingsActionGroup(
                            actions: <SettingsActionButton>[
                              SettingsActionButton(
                                label: l10n.settingsImportExportImportButton,
                                icon: Icons.file_download_outlined,
                                appearance:
                                    SettingsActionButtonAppearance.filled,
                                fullWidth: true,
                                onPressed: _busy || !transferAccess.canBackup
                                    ? null
                                    : () => _runBusy(
                                        () async {
                                          final PortableImportResult?
                                          result = await ref
                                              .read(appSessionProvider.notifier)
                                              .runSensitiveTask((
                                                UnlockedVaultSession session,
                                              ) {
                                                return ref
                                                    .read(
                                                      vaultTransferServiceProvider,
                                                    )
                                                    .importDocumentsWithPicker(
                                                      session,
                                                    );
                                              });
                                          if (result == null) {
                                            return;
                                          }
                                          if (result.importedEntries == 0) {
                                            _showMessage(
                                              result
                                                  .messageWhenNoEntriesImported(
                                                    l10n,
                                                  ),
                                            );
                                            return;
                                          }
                                          await refreshEntryIndexCaches(ref);
                                          _showMessage(
                                            result.formatSuccessMessage(l10n),
                                          );
                                        },
                                        message: l10n
                                            .settingsImportExportImportProgress,
                                      ),
                              ),
                              SettingsActionButton(
                                label: l10n.settingsImportExportExportButton,
                                icon: Icons.file_upload_outlined,
                                appearance:
                                    SettingsActionButtonAppearance.tonal,
                                fullWidth: true,
                                onPressed: _busy || !transferAccess.canBackup
                                    ? null
                                    : () => _runBusy(
                                        () async {
                                          final String? exportPath = await ref
                                              .read(appSessionProvider.notifier)
                                              .runSensitiveTask((
                                                UnlockedVaultSession session,
                                              ) {
                                                return ref
                                                    .read(
                                                      vaultTransferServiceProvider,
                                                    )
                                                    .exportMarkdownToDirectory(
                                                      session,
                                                    );
                                              });
                                          if (exportPath == null) {
                                            return;
                                          }
                                          _showMessage(
                                            l10n.settingsImportExportExportSuccess(
                                              DisplayFormat.formatSavedFileNameForDisplay(
                                                exportPath,
                                              ),
                                            ),
                                          );
                                        },
                                        message: l10n
                                            .settingsImportExportExportProgress,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        LocalBackupSection(
                          access: transferAccess,
                          busy: _busy,
                          onCreate: () =>
                              _runWithBackupProgress(_createLocalBackup),
                          onRestore: _runRestoreFromAppLocalBackup,
                          onExport: () =>
                              _runWithBackupProgress(_exportLocalBackup),
                          onImport: _runRestoreFromLocalBackup,
                        ),
                        const SizedBox(height: 16),
                        DriveBackupSection(
                          access: transferAccess,
                          isGoogleDriveConfigured: isGoogleDriveConfigured,
                          busy: _busy,
                          onLink: () => _runBusy(
                            _linkGoogleDrive,
                            message: l10n.settingsIndexLinkDriveProgress,
                          ),
                          onSwitchAccount: () => _runBusy(
                            _switchGoogleDrive,
                            message:
                                l10n.settingsIndexSwitchDriveAccountProgress,
                          ),
                          onDisconnect: _disconnectGoogleDrive,
                          onUpload: () =>
                              _runWithBackupProgress(_uploadDriveBackup),
                          onRestore: _runRestoreFromGoogleDrive,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildLegalSection(context, cs),
                    ],
                  ),
                ),
              ),
              if (_busy)
                SettingsBlockingProgressOverlay(
                  message: _busyMessage ?? l10n.settingsProgressDefault,
                  progress: _busyProgress,
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
                child: Text(context.l10n.commonActionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.commonActionDelete),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<LocalBackupFile?> _pickLocalBackup(
    List<LocalBackupFile> backups,
  ) async {
    final AppLocalizations l10n = context.l10n;
    if (backups.isEmpty) {
      _showMessage(l10n.settingsLocalBackupNoBackups);
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
      title: l10n.settingsLocalBackupPickDialogTitle,
      emptyMessage: l10n.settingsLocalBackupNoBackups,
      deleteTooltip: l10n.settingsLocalBackupDeleteBackupTooltip,
      actionsDisabled: _busy,
      confirmDelete: (String fileName) => _confirmDeleteBackup(
        title: l10n.settingsLocalBackupDeleteConfirmTitle,
        body: l10n.settingsLocalBackupDeleteConfirmBody(fileName),
      ),
      items: backups
          .map(
            (LocalBackupFile backup) => BackupPickListItem(
              id: backup.path,
              createdAtLabel: _formatLocalBackupTime(backup),
              fileName: backup.name,
              sizeLabel: _formatBytes(backup.sizeBytes),
              onDelete: () async {
                await ref
                    .read(vaultTransferServiceProvider)
                    .deleteAppLocalBackup(backup);
                _showSuccess(
                  l10n.settingsLocalBackupDeleteBackupSuccess(backup.name),
                );
              },
            ),
          )
          .toList(),
    );
    return picked == null ? null : backupsById[picked.id];
  }

  Future<DriveBackupFile?> _pickDriveBackup(
    List<DriveBackupFile> backups,
  ) async {
    final AppLocalizations l10n = context.l10n;
    if (backups.isEmpty) {
      _showMessage(l10n.settingsDriveBackupNoBackups);
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
      title: l10n.settingsDriveBackupPickDialogTitle,
      emptyMessage: l10n.settingsDriveBackupNoBackups,
      deleteTooltip: l10n.settingsDriveBackupDeleteBackupTooltip,
      actionsDisabled: _busy,
      confirmDelete: (String fileName) => _confirmDeleteBackup(
        title: l10n.settingsDriveBackupDeleteConfirmTitle,
        body: l10n.settingsDriveBackupDeleteConfirmBody(fileName),
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
                await ref
                    .read(vaultTransferServiceProvider)
                    .deleteDriveBackup(backup);
                _showSuccess(
                  l10n.settingsDriveBackupDeleteBackupSuccess(backup.name),
                );
              },
            ),
          )
          .toList(),
    );
    return picked == null ? null : backupsById[picked.id];
  }

  String _indexStatusMessage(AppLocalizations l10n, bool hasUnlockedSession) {
    final IndexRebuildReport? report = _lastIndexRebuildReport;
    if (report != null) {
      return l10n.settingsIndexRebuildCompleted(
        report.entryCount,
        DisplayFormat.formatDateTime(l10n, report.finishedAt),
      );
    }
    return hasUnlockedSession
        ? l10n.settingsIndexReadyMessage
        : l10n.settingsIndexLockedMessage;
  }

  Future<void> _createRecoveryKey() async {
    final AppLocalizations l10n = context.l10n;
    final RecoverySetupResult result = await ref
        .read(vaultRepositoryProvider)
        .setupRecoveryKey();
    ref
        .read(appSessionProvider.notifier)
        .activateSession(
          result.session,
          message: sessionRecoverySetupSuccessMessage(l10n),
        );
    ref.invalidate(recoveryMetadataProvider);
    await refreshEntryIndexCaches(ref);
    if (!mounted) {
      return;
    }
    await showRecoveryKeySaveDialog(
      context,
      title: l10n.settingsRecoveryKeySaveDialogTitle,
      recoveryKey: result.recoveryKey,
    );
  }

  Future<void> _persistBackup(
    BackupTaskProgressListener reportProgress,
    Future<BackupPersistResult> Function({
      BackupTaskProgressListener? onProgress,
    })
    persist, {
    required String Function(String savedPath) successMessage,
    String Function(String message)? inspectFailedMessage,
  }) async {
    final BackupPersistResult result = await ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((_) => persist(onProgress: reportProgress));
    _showBackupPersistResult(
      result,
      onSuccess: successMessage,
      inspectFailedMessage: inspectFailedMessage,
    );
  }

  Future<void> _createLocalBackup(BackupTaskProgressListener reportProgress) =>
      _persistBackup(
        reportProgress,
        ref.read(vaultTransferServiceProvider).saveBackupToAppLocal,
        successMessage: (String path) =>
            context.l10n.settingsLocalBackupBackupSuccessInApp(path),
      );

  Future<void> _exportLocalBackup(BackupTaskProgressListener reportProgress) =>
      _persistBackup(
        reportProgress,
        ref.read(vaultTransferServiceProvider).saveBackupToExternalDirectory,
        successMessage: (String path) =>
            context.l10n.settingsLocalBackupBackupExportSuccess(path),
      );

  Future<void> _uploadDriveBackup(BackupTaskProgressListener reportProgress) =>
      _persistBackup(
        reportProgress,
        ref.read(vaultTransferServiceProvider).uploadBackupToDrive,
        successMessage: (String path) =>
            context.l10n.settingsDriveBackupUploadSuccess(path),
        inspectFailedMessage: (String message) =>
            context.l10n.settingsDriveBackupBackupInspectFailed(message),
      );

  Future<void> _runRestoreFromAppLocalBackup() async {
    try {
      final List<LocalBackupFile> backups = await ref
          .read(vaultTransferServiceProvider)
          .listAppLocalBackups();
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
          return ref
              .read(vaultRepositoryProvider)
              .rebuildIndexWithReport(session);
        });
    ref.read(entryIndexRevisionProvider.notifier).bump();
    ref.invalidate(recoveryMetadataProvider);
    if (mounted) {
      setState(() => _lastIndexRebuildReport = report);
      _showMessage(
        context.l10n.settingsIndexRebuildSuccess(
          report.entryCount,
          DisplayFormat.formatDurationMs(report.duration.inMilliseconds),
        ),
      );
    }
  }

  String _formatDriveBackupTime(DateTime? value) {
    if (value == null) {
      return context.l10n.settingsDriveBackupUnknownCreatedTime;
    }
    return DisplayFormat.formatDateTime(context.l10n, value);
  }

  String _formatLocalBackupTime(LocalBackupFile backup) {
    return DisplayFormat.formatDateTime(context.l10n, backup.createdAt);
  }

  String _formatBytes(int bytes) => DisplayFormat.formatBytesForDisplay(bytes);

  Future<void> _runRestoreFromLocalBackup() async {
    final File? backupFile = await ref
        .read(vaultTransferServiceProvider)
        .pickLocalBackupFile();
    if (backupFile == null) {
      return;
    }
    await _restoreBackupFileWithFlow(backupFile);
  }

  Future<void> _runRestoreFromGoogleDrive() async {
    File? tempBackup;
    String? driveBackupName;
    try {
      final List<DriveBackupFile> backups = await ref
          .read(vaultTransferServiceProvider)
          .listDriveBackups();
      final DriveBackupFile? backup = await _pickDriveBackup(backups);
      if (backup == null) {
        return;
      }
      driveBackupName = backup.name;
      await _runWithBackupProgress((
        BackupTaskProgressListener reportProgress,
      ) async {
        tempBackup = await ref
            .read(vaultTransferServiceProvider)
            .downloadDriveBackupToTempFile(backup, onProgress: reportProgress);
      });
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
    final AppLocalizations l10n = context.l10n;
    final DriveConnectionState connectionState = await ref
        .read(vaultTransferServiceProvider)
        .linkGoogleDrive();
    if (!mounted) return;
    ref.invalidate(settingsDriveConnectionProvider);
    await ref.read(settingsDriveConnectionProvider.future);
    if (!mounted) return;
    _showSuccess(settingsDriveLinkSuccess(l10n, connectionState.accountLabel));
  }

  Future<void> _switchGoogleDrive() async {
    final AppLocalizations l10n = context.l10n;
    final DriveConnectionState connectionState = await ref
        .read(vaultTransferServiceProvider)
        .switchGoogleDrive();
    if (!mounted) return;
    ref.invalidate(settingsDriveConnectionProvider);
    await ref.read(settingsDriveConnectionProvider.future);
    if (!mounted) return;
    _showSuccess(
      settingsDriveSwitchAccountSuccess(l10n, connectionState.accountLabel),
    );
  }

  Future<void> _disconnectGoogleDrive() async {
    final AppLocalizations l10n = context.l10n;
    if (!mounted) {
      return;
    }
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.settingsDriveBackupDisconnectConfirmTitle),
            content: Text(l10n.settingsDriveBackupDisconnectConfirmBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonActionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.settingsDriveBackupDisconnectButton),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await _runBusy(
      () => ref.read(vaultTransferServiceProvider).disconnectGoogleDrive(),
      message: l10n.settingsIndexDisconnectDriveProgress,
    );
    ref.invalidate(settingsDriveConnectionProvider);
    await ref.read(settingsDriveConnectionProvider.future);
    _showSuccess(l10n.settingsDriveBackupDisconnectSuccess);
  }

  Future<void> _restoreBackupFileWithFlow(
    File backupFile, {
    String? driveBackupName,
  }) async {
    try {
      final RestorePrecheck precheck = await ref
          .read(vaultTransferServiceProvider)
          .precheckRestore(backupFile);
      if (!mounted) {
        return;
      }
      final RestoreBackupFlow flow = RestoreBackupFlow(ref);
      final RestorePreparedContext? prepared = await flow.prepare(
        context: context,
        backupFile: backupFile,
        precheck: precheck,
        driveBackupName: driveBackupName,
        confirm: _confirmRestore,
      );
      if (prepared == null) {
        return;
      }
      await _runWithBackupProgress((
        BackupTaskProgressListener reportProgress,
      ) async {
        final AppSessionState sessionState = await flow
            .executeRestoreAndFinishSession(
              backupFile: backupFile,
              prepared: prepared,
              onProgress: reportProgress,
            );
        await _presentRestoreSuccess(
          sessionState: sessionState,
          prepared: prepared,
          driveBackupName: driveBackupName,
        );
      });
    } on StateError catch (error) {
      _showError(userFacingErrorMessage(error));
    }
  }

  Future<bool> _confirmRestore(
    RestorePrecheck precheck, {
    String? driveBackupName,
  }) async {
    final AppLocalizations l10n = context.l10n;
    final List<String> bullets = buildRestoreConfirmBulletPoints(
      l10n,
      precheck,
    );
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(
                driveBackupName == null
                    ? l10n.settingsRestoreDialogConfirmLocalTitle
                    : l10n.settingsRestoreDialogConfirmDriveTitle,
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (driveBackupName != null) ...<Widget>[
                      Text(
                        l10n.settingsRestoreDialogDriveFileLine(
                          driveBackupName,
                        ),
                      ),
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
                  child: Text(l10n.commonActionCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.settingsActionConfirm),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _presentRestoreSuccess({
    required AppSessionState sessionState,
    required RestorePreparedContext prepared,
    String? driveBackupName,
  }) async {
    if (!mounted) {
      return;
    }

    final String? trimmedKey = prepared.backupRecoveryKey?.trim();
    if (trimmedKey != null &&
        trimmedKey.isNotEmpty &&
        sessionState.status != AppLockStatus.unlocked) {
      _showError(
        sessionState.message ?? context.l10n.vaultTransferRestoreUnlockFailed,
      );
      return;
    }

    context.go(AppRouter.homeRoute);
    _showSuccess(
      driveAwarePostRestoreSnackBarMessage(
        l10n: context.l10n,
        status: sessionState.status,
        sessionMessage: sessionState.message,
        driveBackupName: driveBackupName,
      ),
    );
  }

  Future<void> _retryTrustedUnlock() async {
    final UnlockOutcome outcome = await ref
        .read(appSessionProvider.notifier)
        .unlock();
    if (outcome == UnlockOutcome.success) {
      await refreshEntryIndexCaches(ref);
    }
  }

  Future<void> _applyUnlockMode(AppUnlockMode mode) async {
    final AppLocalizations l10n = context.l10n;
    final UnlockModeChangeOutcome outcome = await applyUnlockModeChange(
      ref: ref,
      mode: mode,
    );
    if (!mounted) {
      return;
    }
    if (outcome is UnlockModeChangeMessage) {
      _showMessage(unlockModeChangeMessage(l10n, outcome.kind));
    }
  }

  Future<void> _rotateRecoveryKey() async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(l10n.settingsRecoveryKeyRotateDialogTitle),
              content: Text(l10n.settingsRecoveryKeyRotateDialogBody),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.commonActionCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.settingsActionUpdate),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await ref.read(appSessionProvider.notifier).runSensitiveTask((
      UnlockedVaultSession session,
    ) async {
      final RecoverySetupResult result = await ref
          .read(vaultRepositoryProvider)
          .rotateRecoveryKey(session);
      ref
          .read(appSessionProvider.notifier)
          .activateSession(
            result.session,
            message: sessionRecoveryKeyRotatedMessage(l10n),
          );
      ref.invalidate(recoveryMetadataProvider);
      await refreshEntryIndexCaches(ref);
      if (!mounted) {
        return;
      }
      await showRecoveryKeySaveDialog(
        context,
        title: l10n.settingsRecoveryKeySaveNewDialogTitle,
        recoveryKey: result.recoveryKey,
      );
    });
  }

  Future<void> _runBusy(
    Future<void> Function() action, {
    String? message,
  }) async {
    setState(() {
      _busy = true;
      _busyMessage = message;
      _busyProgress = null;
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
          _busyProgress = null;
        });
      }
    }
  }

  Future<void> _runWithBackupProgress(
    Future<void> Function(BackupTaskProgressListener reportProgress) action,
  ) async {
    void reportProgress(BackupTaskProgress progress) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyMessage = settingsBackupTaskProgressLabel(context.l10n, progress);
        _busyProgress = progress.fraction;
      });
    }

    setState(() {
      _busy = true;
      _busyMessage = null;
      _busyProgress = null;
    });
    try {
      await action(reportProgress);
    } catch (error) {
      _showError(userFacingErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
          _busyProgress = null;
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
            inspectFailedMessage ??
            (String message) =>
                context.l10n.settingsLocalBackupBackupInspectFailed(message);
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

/// 設定頁 AppBar 右側按鈕列（個人化、介紹、支持）。
class _SettingsTopNavSection extends StatelessWidget {
  const _SettingsTopNavSection();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          cs.surfaceContainerLowest.withValues(alpha: 0.9),
          cs.surface,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: _SettingsAppBarNavActions(),
      ),
    );
  }
}

class _SettingsAppBarNavActions extends StatelessWidget {
  const _SettingsAppBarNavActions();

  static const double _gap = 8;
  static const double _horizontalPadding = 16;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _SettingsAppBarNavButton(
                label: context.l10n.personalizationNavButtonLabel,
                icon: Icons.tune_rounded,
                onPressed: () =>
                    unawaited(context.push(AppRouter.personalizationRoute)),
              ),
              const SizedBox(width: _gap),
              _SettingsAppBarNavButton(
                label: context.l10n.aboutPageTitle,
                icon: Icons.info_outline_rounded,
                onPressed: () => unawaited(context.push(AppRouter.aboutRoute)),
              ),
              const SizedBox(width: _gap),
              _SettingsAppBarNavButton(
                label: context.l10n.settingsSupportNavButtonLabel,
                icon: Icons.favorite_border_rounded,
                onPressed: () =>
                    unawaited(context.push(AppRouter.supportRoute)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsAppBarNavButton extends StatelessWidget {
  const _SettingsAppBarNavButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Material(
      color: Color.alphaBlend(
        cs.surfaceContainerHigh.withValues(alpha: 0.9),
        cs.surface,
      ),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.9)),
        ),
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    height: 1,
                  ),
                ),
              ],
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

String _sessionSummary(AppLocalizations l10n, AppSessionState sessionState) {
  final String? message = sessionState.message;
  return switch (sessionState.status) {
    AppLockStatus.uninitialized =>
      message ?? l10n.settingsSecurityLockStatusPreparing,
    AppLockStatus.unlocking =>
      message ?? sessionTrustedUnlockInProgressMessage(l10n),
    AppLockStatus.unlocked =>
      message ?? l10n.settingsSecurityLockStatusUnlocked,
    AppLockStatus.locked =>
      message ?? sessionLockedRetryVerificationMessage(l10n),
    AppLockStatus.recoveryRequired =>
      message ?? sessionRecoveryRequiredAfterRestoreMessage(l10n),
    AppLockStatus.fatalError =>
      message ?? l10n.settingsSecurityLockStatusFatalError,
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
