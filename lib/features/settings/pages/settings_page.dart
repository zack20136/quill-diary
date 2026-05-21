import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../domain/recovery/recovery_metadata.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../infrastructure/drive/drive_backup_service.dart';
import '../../../infrastructure/security/app_lock_service.dart';
import '../../../infrastructure/security/app_unlock_mode.dart';
import '../../../infrastructure/storage/restore_precheck.dart';
import '../../../infrastructure/storage/vault_repository.dart';
import '../../../infrastructure/storage/vault_archive_io.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/providers/core_providers.dart';
import '../../editor/providers/editor_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../session/providers/session_providers.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
import '../../session/state/resume_unlock_action.dart';
import '../../session/state/unlock_result.dart';
import '../providers/settings_providers.dart';
import '../settings_copy.dart';
import '../../restore/restore_backup_flow.dart';
import '../../session/application/session_unlock_coordinator.dart';
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
  bool _unlockCoordinatorAttached = false;

  @override
  void dispose() {
    _recoveryKeyInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlockCoordinatorAttached) {
      _unlockCoordinatorAttached = true;
      SessionUnlockCoordinator(ref).listen();
    }

    final bool isSupportedPlatform = ref.watch(supportedPlatformProvider);
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(effectiveAppSessionProvider);
    final AsyncValue<RecoveryMetadata?> recoveryMetadataAsync = ref.watch(recoveryMetadataProvider);
    final AppLockService appLockService = ref.watch(appLockServiceProvider);
    final AppSessionState? sessionState = sessionAsync.asData?.value;
    final RecoveryMetadata? recoveryMetadata = recoveryMetadataAsync.asData?.value;
    final bool hasUnlockedSession =
        sessionState?.isUnlocked == true && sessionState?.session != null;
    final bool hasRecoveryKey = recoveryMetadata != null;
    final bool canSensitiveVaultTransfer = hasUnlockedSession && hasRecoveryKey;
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
                  sessionAsync.when(
                    data: (AppSessionState sessionState) {
                      return SettingsSectionCard(
                        title: SettingsSecurityLockCopy.sectionTitle,
                        description: SettingsSecurityLockCopy.sectionDescription,
                        child: SettingsStatusPanel(
                          sessionState: sessionState,
                          busy: _busy,
                          recoveryKeyInputController: _recoveryKeyInputController,
                          recoveryKeyHint: recoveryMetadataAsync.asData?.value?.recoveryKeyHint,
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
                              sessionState.status == AppLockStatus.locked ||
                                      sessionState.status == AppLockStatus.unlocking
                                  ? () => _runAction(_retryTrustedUnlock)
                                  : null,
                          onUnlockWithDeviceCredential:
                              sessionState.status == AppLockStatus.locked &&
                                      sessionState.resumeAction ==
                                          ResumeUnlockAction.deviceCredentialFallback
                                  ? () => _runAction(_unlockWithDeviceCredential)
                                  : null,
                          onCancelUnlock: sessionState.status == AppLockStatus.unlocking
                              ? () => _runAction(() async {
                                    await ref.read(appSessionProvider.notifier).lock();
                                  })
                              : null,
                          retryActionLabel: _retryUnlockLabel(sessionState),
                        ),
                      );
                    },
                    loading: () => const SettingsSectionLoading(),
                    error: (Object error, StackTrace _) => SettingsSectionCard(
                      title: SettingsSecurityLockCopy.sectionTitle,
                      description: SettingsSecurityLockCopy.loadErrorDescription,
                      child: SettingsInfoBanner(
                        icon: Icons.error_outline_rounded,
                        message: '$error',
                        tone: SettingsBannerTone.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  recoveryMetadataAsync.when(
                    data: (RecoveryMetadata? metadata) {
                      return SettingsSectionCard(
                        title: SettingsRecoveryKeyCopy.sectionTitle,
                        description: SettingsRecoveryKeyCopy.sectionDescription,
                        child: RecoveryKeySectionBody(
                          metadata: metadata,
                          busy: _busy,
                          onRotateRecoveryKey: metadata != null && canSensitiveVaultTransfer
                              ? () => _runAction(_rotateRecoveryKey)
                              : null,
                          onCreateRecoveryKey: metadata != null
                              ? null
                              : () => _runAction(() async {
                                    final result = await ref.read(vaultRepositoryProvider).setupRecoveryKey();
                                    ref.read(appSessionProvider.notifier).activateSession(
                                          result.session,
                                          message: kRecoverySetupSuccessMessage,
                                        );
                                    ref.invalidate(recoveryMetadataProvider);
                                    await refreshEntryIndexCaches(ref);
                                    if (!context.mounted) {
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
                                  }),
                        ),
                      );
                    },
                    loading: () => const SettingsSectionLoading(),
                    error: (Object error, StackTrace _) => SettingsSectionCard(
                      title: SettingsRecoveryKeyCopy.sectionTitle,
                      description: SettingsRecoveryKeyCopy.loadErrorDescription,
                      child: SettingsInfoBanner(
                        icon: Icons.error_outline_rounded,
                        message: '$error',
                        tone: SettingsBannerTone.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    title: SettingsUnlockMethodCopy.sectionTitle,
                    description: SettingsUnlockMethodCopy.sectionDescription,
                    child: FutureBuilder<AppUnlockMode>(
                      future: appLockService.getUnlockMode(),
                      builder: (BuildContext context, AsyncSnapshot<AppUnlockMode> snapshot) {
                        final AppUnlockMode mode =
                            snapshot.data ?? AppUnlockMode.none;
                        return UnlockMethodSectionBody(
                          enabled: recoveryMetadataAsync.asData?.value != null,
                          busy: _busy,
                          unlockMode: mode,
                          onModeSelected: (AppUnlockMode selected) =>
                              _runAction(() => _applyUnlockMode(selected)),
                        );
                      },
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
                                    _showMessage(SettingsImportExportCopy.exportSuccess(exportPath));
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
                                    if (result == null || result.importedEntries == 0) {
                                      return;
                                    }
                                    await refreshEntryIndexCaches(ref);
                                    final String importMessage = result.skippedFiles > 0
                                        ? SettingsImportExportCopy.importSuccessWithSkipped(
                                            result.importedEntries,
                                            result.skippedFiles,
                                          )
                                        : SettingsImportExportCopy.importSuccess(
                                            result.importedEntries,
                                          );
                                    _showMessage(importMessage);
                                  }),
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
                              : () => _runAction(() async {
                                    final String? savedPath = await ref
                                        .read(appSessionProvider.notifier)
                                        .runSensitiveTask((_) {
                                      return ref
                                          .read(vaultTransferServiceProvider)
                                          .createBackupWithPicker();
                                    });
                                    if (savedPath == null) {
                                      return;
                                    }
                                    _showMessage(SettingsLocalBackupCopy.createSuccess(savedPath));
                                  }),
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
                  SettingsSectionCard(
                    icon: Icons.cloud_outlined,
                    title: SettingsDriveBackupCopy.sectionTitle,
                    description: canSensitiveVaultTransfer
                        ? SettingsDriveBackupCopy.sectionDescriptionEnabled
                        : disabledSensitiveVaultTransferReason,
                    child: SettingsActionGroup(
                      actions: <SettingsActionButton>[
                        SettingsActionButton(
                          label: SettingsDriveBackupCopy.uploadButton,
                          icon: Icons.cloud_upload_outlined,
                          emphasized: true,
                          fullWidth: true,
                          onPressed: _busy || !canSensitiveVaultTransfer
                              ? null
                              : () => _runAction(() async {
                                    await ref
                                        .read(appSessionProvider.notifier)
                                        .runSensitiveTask((_) {
                                      return ref
                                          .read(vaultTransferServiceProvider)
                                          .uploadBackupToDrive();
                                    });
                                    _showMessage(SettingsDriveBackupCopy.uploadSuccess);
                                  }),
                        ),
                        SettingsActionButton(
                          label: SettingsDriveBackupCopy.restoreButton,
                          icon: Icons.cloud_download_outlined,
                          fullWidth: true,
                          onPressed: _busy || !canSensitiveVaultTransfer
                              ? null
                              : () => _runRestoreFromGoogleDrive(),
                        ),
                      ],
                    ),
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
      _showMessage(error.message);
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
        final String text = error is StateError ? error.message : '$error';
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
    ref.read(entryIndexRevisionProvider.notifier).bump();
  }

  String _retryUnlockLabel(AppSessionState sessionState) {
    return switch (sessionState.resumeAction) {
      ResumeUnlockAction.keystoreUnlock => SettingsSecurityLockCopy.retryVerificationButton,
      ResumeUnlockAction.deviceCredentialFallback =>
          SettingsSecurityLockCopy.unlockWithDeviceLockButton,
      _ => SettingsSecurityLockCopy.retryVerificationButton,
    };
  }

  Future<void> _retryTrustedUnlock() async {
    final UnlockOutcome outcome = await ref.read(appSessionProvider.notifier).unlock();
    if (outcome == UnlockOutcome.needsUserStep) {
      await _unlockWithDeviceCredential();
      return;
    }
    if (outcome == UnlockOutcome.success) {
      await refreshEntryIndexCaches(ref);
    }
  }

  Future<void> _unlockWithDeviceCredential() async {
    final UnlockOutcome outcome = await ref
        .read(appSessionProvider.notifier)
        .unlock(deviceCredentialFallback: true);
    if (outcome == UnlockOutcome.success) {
      await refreshEntryIndexCaches(ref);
    }
  }

  Future<void> _applyUnlockMode(AppUnlockMode mode) async {
    final AppLockService appLock = ref.read(appLockServiceProvider);
    final AppUnlockMode current = await appLock.getUnlockMode();
    if (current == mode) {
      return;
    }

    if (mode == AppUnlockMode.deviceLock && !await appLock.canUseDeviceCredential()) {
      _showMessage(kUnlockModeNeedsDeviceLockMessage);
      return;
    }

    if (mode == AppUnlockMode.biometric && !await appLock.canUseDeviceCredential()) {
      _showMessage(kUnlockModeNeedsDeviceLockMessage);
      return;
    }

    await appLock.setUnlockMode(mode);
    final UnlockedVaultSession? session = await ref.read(activeVaultSessionProvider.future);
    if (session != null) {
      final UnlockedVaultSession synced = await ref
          .read(vaultRepositoryProvider)
          .ensureKeystoreMatchesUnlockMode(session);
      ref.read(appSessionProvider.notifier).activateSession(synced);
    }
    if (mounted) {
      setState(() {});
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
      final String text = error is StateError ? error.message : '$error';
      if (_shouldOfferGooglePermissionsHelp(text)) {
        _showGoogleDriveHelpSnackBar(text, action);
      } else {
        _showMessage(text);
      }
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

  Future<void> _retryGoogleDriveAfterSignOut(Future<void> Function() action) async {
    await ref.read(vaultTransferServiceProvider).resetGoogleDriveSignInForConsentRetry();
    await _runAction(action);
  }

  void _showGoogleDriveHelpSnackBar(String message, Future<void> Function() action) {
    if (!mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(message),
            const SizedBox(height: 10),
            const Text(
              SettingsDriveBackupCopy.googleHelpHint,
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  unawaited(_retryGoogleDriveAfterSignOut(action));
                },
                child: const Text(SettingsDriveBackupCopy.googleHelpRetryButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldOfferGooglePermissionsHelp(String message) {
    return message.contains('Google 帳號') ||
        message.contains('Google 雲端硬碟') ||
        message.contains('oauth_config.xml') ||
        message.contains('Cloud Console') ||
        message.contains('No credential available') ||
        message.contains('GIDClientID') ||
        message.contains('GIDServerClientID');
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
