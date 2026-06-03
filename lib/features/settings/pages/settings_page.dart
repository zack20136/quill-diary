import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

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
import '../../../shared/presentation/page_style.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/utils/user_facing_error.dart';
import '../../editor/providers/editor_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../session/providers/session_providers.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
import '../../session/state/unlock_result.dart';
import '../providers/settings_providers.dart';
import '../portable_import_result_messages.dart';
import '../settings_copy.dart';
import '../unlock_mode_change.dart';
import '../../restore/restore_backup_flow.dart';
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

  Widget _buildSecurityStatusSection({
    required AsyncValue<AppSessionState> sessionAsync,
    required RecoveryMetadata? recoveryMetadata,
    required bool canSensitiveVaultTransfer,
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
            hasUnlockedSession: hasUnlockedSession,
            hasTrustedDevice: hasTrustedDevice,
            unlockModeLabel: mode.fullLabel,
            indexMessage: _indexStatusMessage(hasUnlockedSession),
            busy: _busy,
            onCreateRecoveryKey:
                recoveryMetadata == null ? () => _runAction(_createRecoveryKey) : null,
            onRotateRecoveryKey:
                recoveryMetadata != null && canSensitiveVaultTransfer
                    ? () => _runAction(_rotateRecoveryKey)
                    : null,
            onRebuildIndex:
                hasUnlockedSession ? () => _runAction(_rebuildIndex) : null,
            lockPanel: sessionAsync.when(
              data: (AppSessionState sessionState) => SettingsStatusPanel(
                sessionState: sessionState,
                busy: _busy,
                recoveryKeyInputController: _recoveryKeyInputController,
                recoveryKeyHint: recoveryMetadata?.recoveryKeyHint,
                bannerIcon: _sessionIcon(sessionState.status),
                bannerMessage: _sessionSummary(sessionState),
                bannerTone: _sessionTone(sessionState.status),
                onUnlockWithRecovery: sessionState.status == AppLockStatus.recoveryRequired
                    ? () => _runAction(() async {
                          await ref.read(appSessionProvider.notifier).unlockWithRecovery(
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
    final bool canSensitiveVaultTransfer = hasUnlockedSession && hasRecoveryKey;
    final bool isGoogleDriveConfigured =
        !Platform.isIOS || OAuthConfig.isIosGoogleDriveConfigured;
    final AsyncValue<DriveConnectionState> driveConnectionAsync = isGoogleDriveConfigured
        ? ref.watch(settingsDriveConnectionProvider)
        : const AsyncData<DriveConnectionState>(DriveConnectionState.disconnected());
    final String disabledSensitiveVaultTransferReason =
        sensitiveVaultTransferDisabledReason(
          hasUnlockedSession: hasUnlockedSession,
          hasRecoveryKey: hasRecoveryKey,
        );

    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Text(SettingsCopy.pageTitle),
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => unawaited(context.push(AppRouter.securityInfoRoute)),
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text('說明'),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 12, bottom: 8),
            child: FilledButton.tonalIcon(
              onPressed: () => unawaited(context.push(AppRouter.supportRoute)),
              icon: const Icon(Icons.favorite_border_rounded, size: 18),
              label: const Text('\u8d0a\u52a9'),
            ),
          ),
        ],
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
                    canSensitiveVaultTransfer: canSensitiveVaultTransfer,
                    unlockModeAsync: unlockModeAsync,
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    title: SettingsUnlockMethodCopy.sectionTitle,
                    description: SettingsUnlockMethodCopy.sectionDescription,
                    child: unlockModeAsync.when(
                      data: (AppUnlockMode unlockMode) => UnlockMethodSectionBody(
                        enabled: recoveryMetadataAsync.asData?.value != null,
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
                    description: canSensitiveVaultTransfer
                        ? SettingsImportExportCopy.sectionDescriptionEnabled
                        : disabledSensitiveVaultTransferReason,
                    child: SettingsActionGroup(
                      actions: <SettingsActionButton>[
                        SettingsActionButton(
                          label: SettingsImportExportCopy.exportButton,
                          icon: Icons.file_open_outlined,
                          emphasized: true,
                          fullWidth: true,
                          onPressed: _busy || !canSensitiveVaultTransfer
                              ? null
                              : () => _runAction(
                                    () async {
                                    final String? exportPath = await ref
                                        .read(appSessionProvider.notifier)
                                        .runSensitiveTask((UnlockedVaultSession session) {
                                      return ref
                                          .read(vaultTransferServiceProvider)
                                          .exportMarkdownWithPicker(session);
                                    });
                                    if (exportPath == null) {
                                      return;
                                    }
                                    _showMessage(
                                      SettingsImportExportCopy.exportSuccess(
                                        p.basename(exportPath),
                                      ),
                                    );
                                  },
                                    progressMessage: SettingsImportExportCopy.exportProgress,
                                  ),
                        ),
                        SettingsActionButton(
                          label: SettingsImportExportCopy.importButton,
                          icon: Icons.download_rounded,
                          fullWidth: true,
                          onPressed: _busy || !canSensitiveVaultTransfer
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    icon: Icons.storage_rounded,
                    title: SettingsLocalBackupCopy.sectionTitle,
                    description: canSensitiveVaultTransfer
                        ? SettingsLocalBackupCopy.sectionDescriptionEnabled
                        : disabledSensitiveVaultTransferReason,
                    child: SettingsActionGroup(
                      actions: <SettingsActionButton>[
                        SettingsActionButton(
                          label: SettingsLocalBackupCopy.createButton,
                          icon: Icons.archive_outlined,
                          emphasized: true,
                          fullWidth: true,
                          onPressed: _busy || !canSensitiveVaultTransfer
                              ? null
                              : () => _runAction(_createLocalBackup),
                        ),
                        SettingsActionButton(
                          label: SettingsLocalBackupCopy.restoreButton,
                          icon: Icons.restore_rounded,
                          fullWidth: true,
                          onPressed: _busy || !canSensitiveVaultTransfer
                              ? null
                              : () => _runRestoreFromLocalBackup(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDriveBackupSection(
                    isGoogleDriveConfigured: isGoogleDriveConfigured,
                    driveConnectionAsync: driveConnectionAsync,
                    canSensitiveVaultTransfer: canSensitiveVaultTransfer,
                    disabledSensitiveVaultTransferReason:
                        disabledSensitiveVaultTransferReason,
                  ),
                ],
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

  Future<DriveBackupFile?> _pickDriveBackup(List<DriveBackupFile> backups) async {
    if (backups.isEmpty) {
      _showMessage(SettingsDriveBackupCopy.noBackups);
      return null;
    }
    if (!mounted) {
      return null;
    }
    return showDialog<DriveBackupFile>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(SettingsDriveBackupCopy.pickDialogTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: backups.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final DriveBackupFile backup = backups[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_done_outlined),
                  title: Text(backup.name),
                  subtitle: Text(_formatDriveBackupTime(backup.createdAt)),
                  onTap: () => Navigator.of(dialogContext).pop(backup),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(SettingsCopy.actionCancel),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDriveBackupSection({
    required bool isGoogleDriveConfigured,
    required AsyncValue<DriveConnectionState> driveConnectionAsync,
    required bool canSensitiveVaultTransfer,
    required String disabledSensitiveVaultTransferReason,
  }) {
    final String description = isGoogleDriveConfigured
        ? SettingsDriveBackupCopy.sectionDescriptionEnabled
        : SettingsDriveBackupCopy.sectionDescriptionOAuthNotConfigured;

    return SettingsSectionCard(
      icon: Icons.cloud_outlined,
      title: SettingsDriveBackupCopy.sectionTitle,
      description: description,
      child: !isGoogleDriveConfigured
          ? const SettingsInfoBanner(
              icon: Icons.cloud_off_rounded,
              message: SettingsDriveBackupCopy.sectionDescriptionOAuthNotConfigured,
            )
          : driveConnectionAsync.when(
              loading: () => const SettingsSectionLoading(),
              error: (_, _) => _buildDriveBackupContent(
                connectionState: const DriveConnectionState.disconnected(),
                canSensitiveVaultTransfer: canSensitiveVaultTransfer,
                disabledSensitiveVaultTransferReason:
                    disabledSensitiveVaultTransferReason,
              ),
              data: (DriveConnectionState connectionState) => _buildDriveBackupContent(
                connectionState: connectionState,
                canSensitiveVaultTransfer: canSensitiveVaultTransfer,
                disabledSensitiveVaultTransferReason:
                    disabledSensitiveVaultTransferReason,
              ),
            ),
    );
  }

  Widget _buildDriveBackupContent({
    required DriveConnectionState connectionState,
    required bool canSensitiveVaultTransfer,
    required String disabledSensitiveVaultTransferReason,
  }) {
    final bool isConnected = connectionState.isConnected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsInfoBanner(
          icon: isConnected ? Icons.cloud_done_outlined : Icons.cloud_off_rounded,
          message: isConnected
              ? SettingsDriveBackupCopy.connectedHint(connectionState.accountLabel)
              : SettingsDriveBackupCopy.disconnectedHint,
        ),
        const SizedBox(height: 12),
        SettingsActionGroup(
          actions: <SettingsActionButton>[
            if (!isConnected)
              SettingsActionButton(
                label: SettingsDriveBackupCopy.connectButton,
                icon: Icons.link_rounded,
                emphasized: true,
                fullWidth: true,
                onPressed: _busy
                    ? null
                    : () => _runAction(
                          () => _connectGoogleDrive(),
                          progressMessage: '正在連結 Google Drive…',
                        ),
              ),
            if (isConnected)
              SettingsActionButton(
                label: SettingsDriveBackupCopy.uploadButton,
                icon: Icons.cloud_upload_outlined,
                emphasized: true,
                fullWidth: true,
                onPressed: _busy || !canSensitiveVaultTransfer
                    ? null
                    : () => _runAction(() async {
                          await ref.read(appSessionProvider.notifier).runSensitiveTask((_) {
                            return ref.read(vaultTransferServiceProvider).uploadBackupToDrive();
                          });
                          _showMessage(SettingsDriveBackupCopy.uploadSuccess);
                        }),
              ),
            if (isConnected)
              SettingsActionButton(
                label: SettingsDriveBackupCopy.restoreButton,
                icon: Icons.cloud_download_outlined,
                fullWidth: true,
                onPressed:
                    _busy || !canSensitiveVaultTransfer ? null : () => _runRestoreFromGoogleDrive(),
              ),
          ],
        ),
        if (isConnected) ...<Widget>[
          const SizedBox(height: 8),
          const SettingsInfoBanner(
            icon: Icons.history_rounded,
            message: 'Google Drive 會自動保留最新 10 份 .jbackup 備份。',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => _runAction(
                        () => _connectGoogleDrive(reconnect: true),
                        progressMessage: '正在重新連結 Google Drive…',
                      ),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text(SettingsDriveBackupCopy.reconnectButton),
            ),
          ),
        ],
        if (!canSensitiveVaultTransfer && isConnected) ...<Widget>[
          const SizedBox(height: 12),
          SettingsInfoBanner(
            icon: Icons.lock_outline_rounded,
            message: disabledSensitiveVaultTransferReason.isEmpty
                ? SettingsDriveBackupCopy.actionsLockedHint
                : disabledSensitiveVaultTransferReason,
          ),
        ],
      ],
    );
  }

  String _indexStatusMessage(bool hasUnlockedSession) {
    final IndexRebuildReport? report = _lastIndexRebuildReport;
    if (report != null) {
      return '最近重建完成：${report.entryCount} 篇日記，${report.finishedAt.toLocal().toString().replaceFirst('.000', '')}。';
    }
    return hasUnlockedSession ? '可隨時從加密日記重建。' : '解鎖後可重建索引。';
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
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(SettingsRecoveryKeyCopy.saveDialogTitle),
        content: SelectableText(result.recoveryKey),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(SettingsCopy.actionClose),
          ),
        ],
      ),
    );
  }

  Future<void> _createLocalBackup() async {
    final BackupCreationResult? result = await ref
        .read(appSessionProvider.notifier)
        .runSensitiveTask((_) {
      return ref.read(vaultTransferServiceProvider).createBackupWithPicker();
    });
    if (result == null) {
      return;
    }
    final String message = result.healthReport.ok
        ? SettingsLocalBackupCopy.createSuccess(p.basename(result.path))
        : '備份已建立，但檢查未通過。\n${result.healthReport.message}\n'
            '檔案：${p.basename(result.path)}';
    _showMessage(message);
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
    _showMessage('索引已重建：${report.entryCount} 篇日記，耗時 ${report.duration.inMilliseconds} ms');
  }

  String _formatDriveBackupTime(DateTime? value) {
    if (value == null) {
      return SettingsDriveBackupCopy.unknownCreatedTime;
    }
    return value.toLocal().toString().replaceFirst('.000', '');
  }

  Future<void> _runRestoreFromLocalBackup() async {
    final File? backupFile =
        await ref.read(vaultTransferServiceProvider).pickLocalBackupFile();
    if (backupFile == null) {
      return;
    }
    await _restoreBackupFileWithFlow(backupFile);
  }

  Future<void> _runRestoreFromGoogleDrive() async {
    await _runAction(() async {
      final List<DriveBackupFile> backups = await ref
          .read(appSessionProvider.notifier)
          .runSensitiveTask((_) {
        return ref.read(vaultTransferServiceProvider).listDriveBackups();
      });
      final DriveBackupFile? backup = await _pickDriveBackup(backups);
      if (backup == null) {
        return;
      }
      final File tempBackup = await ref
          .read(appSessionProvider.notifier)
          .runSensitiveTask((_) {
        return ref.read(vaultTransferServiceProvider).downloadDriveBackupToTempFile(backup);
      });
      try {
        await _restoreBackupFileWithFlow(tempBackup, driveBackupName: backup.name);
      } finally {
        if (tempBackup.existsSync()) {
          await tempBackup.delete();
        }
      }
    });
  }

  Future<void> _connectGoogleDrive({bool reconnect = false}) async {
    final DriveConnectionState connectionState =
        await ref.read(vaultTransferServiceProvider).connectGoogleDrive(
          reconnect: reconnect,
        );
    ref.invalidate(settingsDriveConnectionProvider);
    await ref.read(settingsDriveConnectionProvider.future);
    _showMessage(
      reconnect
          ? SettingsDriveBackupCopy.reconnectSuccess(connectionState.accountLabel)
          : SettingsDriveBackupCopy.connectSuccess(connectionState.accountLabel),
    );
  }

  Future<void> _restoreBackupFileWithFlow(
    File backupFile, {
    String? driveBackupName,
  }) async {
    try {
      await _runAction(
        () => RestoreBackupFlow(ref).run(
          context: context,
          backupFile: backupFile,
          driveBackupName: driveBackupName,
          confirm: _confirmRestore,
          onComplete: ({String? backupRecoveryKey, required RestorePrecheck precheck}) =>
              _finishRestoreAfterSuccess(
            backupRecoveryKey: backupRecoveryKey,
            precheck: precheck,
          ),
        ),
        progressMessage: kRestoreInProgressMessage,
      );
    } on StateError catch (error) {
      _showMessage(userFacingErrorMessage(error));
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
    RestorePrecheck? precheck,
  }) async {
    await _resetAppState();

    AppSessionState sessionState;
    if (backupRecoveryKey != null && backupRecoveryKey.trim().isNotEmpty) {
      sessionState = await _unlockRestoredVaultWithRecoveryKey(backupRecoveryKey.trim());
      if (sessionState.status != AppLockStatus.unlocked) {
        return;
      }
    } else if (precheck?.expectsTrustedUnlockAfterRestore == true) {
      final UnlockOutcome outcome = await ref
          .read(appSessionProvider.notifier)
          .unlock(afterRestore: true);
      sessionState = ref.read(appSessionProvider);
      if (outcome == UnlockOutcome.success &&
          sessionState.isUnlocked &&
          sessionState.session != null) {
        await refreshEntryIndexCaches(ref);
      }
    } else {
      sessionState = await ref.read(appStartupProvider.future);
      if (sessionState.isUnlocked && sessionState.session != null) {
        await refreshEntryIndexCaches(ref);
      }
    }

    if (mounted) {
      context.go(AppRouter.homeRoute);
      _showMessage(
        snackbarMessageForPostRestore(
          sessionState.status,
          sessionMessage: sessionState.message,
        ),
      );
    }
  }

  Future<AppSessionState> _unlockRestoredVaultWithRecoveryKey(String recoveryKey) async {
    try {
      await ref.read(appSessionProvider.notifier).unlockWithRecovery(recoveryKey);
      final AppSessionState sessionState = ref.read(appSessionProvider);
      if (sessionState.isUnlocked && sessionState.session != null) {
        await refreshEntryIndexCaches(ref);
      }
      return sessionState;
    } catch (error) {
      if (mounted) {
        final String text = userFacingErrorMessage(error);
        _showMessage(text);
      }
      return ref.read(appSessionProvider);
    }
  }

  Future<void> _resetAppState() async {
    await ref.read(appSessionProvider.notifier).reset();
    ref.invalidate(vaultTransferServiceProvider);
    ref.invalidate(vaultArchiveIoProvider);
    ref.invalidate(vaultRepositoryProvider);
    ref.invalidate(indexDatabaseManagerProvider);
    ref.invalidate(appStartupProvider);
    ref.invalidate(effectiveAppSessionProvider);
    ref.invalidate(recoveryMetadataProvider);
    ref.invalidate(settingsDriveConnectionProvider);
    ref.invalidate(unlockModeProvider);
    ref.read(entryIndexRevisionProvider.notifier).bump();
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
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text(SettingsRecoveryKeyCopy.saveNewDialogTitle),
          content: SelectableText(result.recoveryKey),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('關閉'),
            ),
          ],
        ),
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
      final String text = userFacingErrorMessage(error);
      _showMessage(text);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
