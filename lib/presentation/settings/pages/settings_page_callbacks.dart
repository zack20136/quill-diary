part of 'settings_page.dart';

extension _SettingsPageCallbacks on _SettingsPageState {
  Future<void> _openLegalLink(String url) async {
    final BuildContext context = pageContext;
    final bool opened = await launchExternalUrl(url);
    if (!context.mounted || opened) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    _showFeedback(
      SettingsFlowFeedback(
        l10n.legalExternalLinkUnavailableMessage,
        tone: SettingsFlowFeedbackTone.error,
      ),
    );
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
          Divider(height: 1, color: context.appColors.outlineBorder().color),
          _SettingsLegalRow(
            title: l10n.settingsLegalPrivacyPolicyTitle,
            onTap: () =>
                unawaited(_openLegalLink(AppIdentifiers.privacyPolicyUrl)),
            colorScheme: cs,
          ),
          Divider(height: 1, color: context.appColors.outlineBorder().color),
          _SettingsLegalRow(
            title: l10n.settingsLegalThirdPartyNoticesTitle,
            onTap: () =>
                unawaited(_openLegalLink(AppIdentifiers.thirdPartyNoticesUrl)),
            colorScheme: cs,
          ),
          Divider(height: 1, color: context.appColors.outlineBorder().color),
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
    required SettingsPageCapabilities pageAccess,
    required AsyncValue<bool> trustedDeviceAccessAsync,
    required AsyncValue<AppUnlockMode> unlockModeAsync,
  }) {
    final AppSessionState? sessionState = sessionAsync.asData?.value;
    final bool hasUnlockedSession = pageAccess.hasUnlockedSession;
    final AppUnlockMode mode =
        unlockModeAsync.asData?.value ?? AppUnlockMode.none;
    final AppLocalizations l10n = pageContext.l10n;
    return SettingsSectionCard(
      icon: Icons.health_and_safety_outlined,
      title: l10n.settingsSecurityOverviewSectionTitle,
      description: l10n.settingsSecurityOverviewSectionDescription,
      child: pageRef
          .watch(backupStatusProvider)
          .when(
            loading: () => const SettingsSectionLoading(),
            error: (Object error, StackTrace _) => AppFeedbackBanner(
              icon: Icons.error_outline_rounded,
              message: userFacingErrorMessage(error, l10n: l10n),
              tone: AppFeedbackTone.error,
            ),
            data: (BackupStatusSnapshot backupStatus) =>
                trustedDeviceAccessAsync.when(
                  data: (bool hasTrustedDevice) => SettingsSecurityOverview(
                    hasRecoveryKey: recoveryMetadata != null,
                    recoveryKeyHint: recoveryMetadata?.recoveryKeyHint,
                    hasUnlockedSession: hasUnlockedSession,
                    hasTrustedDevice: hasTrustedDevice,
                    unlockModeLabel: mode.fullLabel(l10n),
                    indexMessage: settingsIndexStatusMessage(
                      l10n,
                      sessionState: sessionState,
                      hasUnlockedSession: hasUnlockedSession,
                      repairReport: _lastVaultRepairReport,
                    ),
                    indexHealthLevel: settingsIndexHealthLevel(
                      l10n: l10n,
                      sessionState: sessionState,
                      hasUnlockedSession: hasUnlockedSession,
                      repairReport: _lastVaultRepairReport,
                    ),
                    backupStatus: backupStatus,
                    busy: _busy,
                    onCreateRecoveryKey: pageAccess.canCreateRecoveryKey
                        ? () => _runBusy(_createRecoveryKey)
                        : null,
                    onRotateRecoveryKey:
                        recoveryMetadata != null &&
                            pageAccess.vaultTransferCapabilities.canBackup
                        ? () => _runBusy(_rotateRecoveryKey)
                        : null,
                    onRepairVault: hasUnlockedSession
                        ? () => _runBusy(_repairVault)
                        : null,
                    onRetryTrustedUnlock:
                        sessionState?.status == AppLockStatus.locked
                        ? () => _runBusy(_retryTrustedUnlock)
                        : null,
                    lockPanel:
                        sessionState?.status == AppLockStatus.unlocked ||
                            sessionState?.status == AppLockStatus.locked
                        ? null
                        : sessionAsync.when(
                            data: (AppSessionState sessionState) =>
                                SettingsStatusPanel(
                                  sessionState: sessionState,
                                  busy: _busy,
                                  recoveryKeyInputController:
                                      _recoveryKeyInputController,
                                  recoveryKeyHint:
                                      recoveryMetadata?.recoveryKeyHint,
                                  bannerIcon: _sessionIcon(sessionState.status),
                                  bannerMessage: _sessionSummary(
                                    l10n,
                                    sessionState,
                                  ),
                                  bannerTone: _sessionTone(sessionState.status),
                                  onUnlockWithRecovery:
                                      sessionState.status ==
                                          AppLockStatus.recoveryRequired
                                      ? () => _runBusy(() async {
                                          _showFeedback(
                                            await _settingsFlow
                                                .unlockWithRecovery(
                                                  l10n,
                                                  _recoveryKeyInputController
                                                      .text
                                                      .trim(),
                                                ),
                                          );
                                        })
                                      : null,
                                  onCancelUnlock:
                                      sessionState.status ==
                                          AppLockStatus.unlocking
                                      ? () => _runBusy(() async {
                                          await _settingsFlow
                                              .cancelRecoveryUnlock();
                                        })
                                      : null,
                                ),
                            loading: () => const SettingsSectionLoading(),
                            error: (Object error, StackTrace _) =>
                                AppFeedbackBanner(
                                  icon: Icons.error_outline_rounded,
                                  message: userFacingErrorMessage(
                                    error,
                                    l10n: l10n,
                                  ),
                                  tone: AppFeedbackTone.error,
                                ),
                          ),
                  ),
                  loading: () => const SettingsSectionLoading(),
                  error: (Object error, StackTrace _) => AppFeedbackBanner(
                    icon: Icons.error_outline_rounded,
                    message: userFacingErrorMessage(error, l10n: l10n),
                    tone: AppFeedbackTone.error,
                  ),
                ),
          ),
    );
  }

  Future<bool> _confirmDeleteBackup({
    required String title,
    required String body,
  }) {
    return showSettingsDeleteBackupDialog(
      context: pageContext,
      title: title,
      body: body,
    );
  }

  Future<LocalBackupFile?> _pickLocalBackup(
    List<LocalBackupFile> backups,
  ) async {
    final AppLocalizations l10n = pageContext.l10n;
    if (backups.isEmpty) {
      _showFeedback(SettingsFlowFeedback(l10n.settingsLocalBackupNoBackups));
      return null;
    }
    if (!isMounted) {
      return null;
    }
    final Map<String, LocalBackupFile> backupsById = <String, LocalBackupFile>{
      for (final LocalBackupFile backup in backups) backup.path: backup,
    };
    final BackupPickListItem? picked = await showSettingsBackupPickerDialog(
      context: pageContext,
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
                await _settingsFlow.deleteAppLocalBackup(backup);
                _showFeedback(
                  SettingsFlowFeedback(
                    l10n.settingsLocalBackupDeleteBackupSuccess(backup.name),
                    tone: SettingsFlowFeedbackTone.success,
                  ),
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
    final AppLocalizations l10n = pageContext.l10n;
    if (backups.isEmpty) {
      _showFeedback(SettingsFlowFeedback(l10n.settingsDriveBackupNoBackups));
      return null;
    }
    if (!isMounted) {
      return null;
    }
    final Map<String, DriveBackupFile> backupsById = <String, DriveBackupFile>{
      for (final DriveBackupFile backup in backups) backup.id: backup,
    };
    final BackupPickListItem? picked = await showSettingsBackupPickerDialog(
      context: pageContext,
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
              createdAtLabel: formatDriveBackupTime(l10n, backup.createdAt),
              fileName: backup.name,
              sizeLabel: backup.sizeBytes == null
                  ? null
                  : _formatBytes(backup.sizeBytes!),
              onDelete: () async {
                await _settingsFlow.deleteDriveBackup(backup);
                _showFeedback(
                  SettingsFlowFeedback(
                    l10n.settingsDriveBackupDeleteBackupSuccess(backup.name),
                    tone: SettingsFlowFeedbackTone.success,
                  ),
                );
              },
            ),
          )
          .toList(),
    );
    return picked == null ? null : backupsById[picked.id];
  }

  Future<void> _importDocuments() async {
    final AppLocalizations l10n = pageContext.l10n;
    _showFeedback(await _settingsFlow.importDocuments(l10n));
  }

  Future<void> _exportMarkdown() async {
    final AppLocalizations l10n = pageContext.l10n;
    _showFeedback(await _settingsFlow.exportMarkdown(l10n));
  }

  Future<void> _createRecoveryKey() async {
    final BuildContext context = pageContext;
    final AppLocalizations l10n = context.l10n;
    final SettingsRecoveryKeyResult result = await _settingsFlow
        .createRecoveryKey(l10n);
    if (!context.mounted) {
      return;
    }
    _showFeedback(result.feedback);
    await showRecoveryKeySaveDialog(
      context,
      title: l10n.settingsRecoveryKeySaveDialogTitle,
      recoveryKey: result.recoveryKey,
    );
  }

  Future<void> _createLocalBackup(
    BackupTaskProgressListener reportProgress,
  ) async {
    final AppLocalizations l10n = pageContext.l10n;
    final BackupPersistResult result = await _settingsFlow.createLocalBackup(
      onProgress: reportProgress,
    );
    await _recordBackupPersistResult(
      result,
      action: BackupStatusAction.localBackup,
      onSuccess: (String path) =>
          l10n.settingsLocalBackupBackupSuccessInApp(path),
    );
  }

  Future<void> _exportLocalBackup(
    BackupTaskProgressListener reportProgress,
  ) async {
    final AppLocalizations l10n = pageContext.l10n;
    final BackupPersistResult result = await _settingsFlow.exportLocalBackup(
      l10n: l10n,
      onProgress: reportProgress,
    );
    await _recordBackupPersistResult(
      result,
      action: BackupStatusAction.externalExport,
      onSuccess: (String path) =>
          l10n.settingsLocalBackupBackupExportSuccess(path),
    );
  }

  Future<void> _uploadDriveBackup(
    BackupTaskProgressListener reportProgress,
  ) async {
    final AppLocalizations l10n = pageContext.l10n;
    String? driveAccountLabel;
    try {
      final DriveConnectionState connection = await pageRef.read(
        settingsDriveConnectionProvider.future,
      );
      driveAccountLabel = connection.accountLabel(l10n);
    } on Object {
      driveAccountLabel = null;
    }
    final BackupPersistResult result = await _settingsFlow.uploadDriveBackup(
      onProgress: reportProgress,
    );
    await _recordBackupPersistResult(
      result,
      action: BackupStatusAction.driveUpload,
      onSuccess: (String path) => l10n.settingsDriveBackupUploadSuccess(path),
      inspectFailedMessage: (String message) =>
          l10n.settingsDriveBackupBackupInspectFailed(message),
      driveAccountLabel: driveAccountLabel,
    );
  }

  Future<void> _runRestoreFromAppLocalBackup() async {
    final AppLocalizations l10n = pageContext.l10n;
    try {
      final PreparedRestoreRequest? request = await _settingsFlow
          .prepareAppLocalRestore(pickBackup: _pickLocalBackup);
      if (request == null) {
        return;
      }
      await _restorePreparedRequest(request);
    } catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    }
  }

  Future<void> _repairVault() async {
    final AppLocalizations l10n = pageContext.l10n;
    final SettingsRepairVaultResult result = await _settingsFlow.repairVault(
      l10n,
    );
    if (!isMounted) {
      return;
    }
    updatePageState(() => _lastVaultRepairReport = result.report);
    _showFeedback(result.feedback);
  }

  String _formatLocalBackupTime(LocalBackupFile backup) {
    final AppLocalizations l10n = pageContext.l10n;
    return DisplayFormat.formatDateTimeWithoutWeekday(l10n, backup.createdAt);
  }

  String _formatBytes(int bytes) => DisplayFormat.formatBytesForDisplay(bytes);

  Future<void> _runRestoreFromLocalBackup() async {
    final AppLocalizations l10n = pageContext.l10n;
    try {
      final PreparedRestoreRequest? request = await _settingsFlow
          .prepareExternalRestore(l10n);
      if (request == null) {
        return;
      }
      await _restorePreparedRequest(request);
    } catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    }
  }

  Future<void> _runRestoreFromGoogleDrive() async {
    final AppLocalizations l10n = pageContext.l10n;
    try {
      final List<DriveBackupFile> backups = await _settingsFlow
          .listDriveBackups();
      final DriveBackupFile? backup = await _pickDriveBackup(backups);
      if (backup == null) {
        return;
      }
      PreparedRestoreRequest? request;
      await _runWithBackupProgress((
        BackupTaskProgressListener reportProgress,
      ) async {
        request = await _settingsFlow.prepareDriveRestore(
          pickBackup: (List<DriveBackupFile> _) async => backup,
          onProgress: reportProgress,
        );
      });
      if (request == null) {
        return;
      }
      await _restorePreparedRequest(request!);
    } catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    }
  }

  Future<void> _linkGoogleDrive() async {
    final AppLocalizations l10n = pageContext.l10n;
    _showFeedback(await _settingsFlow.linkGoogleDrive(l10n));
  }

  Future<void> _switchGoogleDrive() async {
    final AppLocalizations l10n = pageContext.l10n;
    _showFeedback(await _settingsFlow.switchGoogleDrive(l10n));
  }

  Future<void> _disconnectGoogleDrive() async {
    if (!isMounted) {
      return;
    }
    final AppLocalizations l10n = pageContext.l10n;
    final bool confirmed = await showDisconnectDriveDialog(pageContext);
    if (!confirmed) {
      return;
    }
    await _runBusy(() async {
      _showFeedback(await _settingsFlow.disconnectGoogleDrive(l10n));
    }, message: l10n.settingsIndexDisconnectDriveProgress);
  }

  Future<void> _restorePreparedRequest(PreparedRestoreRequest request) async {
    final AppLocalizations l10n = pageContext.l10n;
    try {
      if (!isMounted) {
        return;
      }
      final bool confirmed = await showRestoreConfirmDialog(
        pageContext,
        request.precheck,
        driveBackupName: request.driveBackupName,
      );
      if (!confirmed || !isMounted) {
        return;
      }
      String? backupRecoveryKey;
      if (request.precheck.expectsRecoveryKeyAfterRestore) {
        backupRecoveryKey = await _collectValidatedRestoreRecoveryKey(
          backupFile: request.backupFile,
          precheck: request.precheck,
        );
        if (!isMounted || backupRecoveryKey == null) {
          return;
        }
      }
      SettingsRestoreResult? result;
      await _runWithBackupProgress((
        BackupTaskProgressListener reportProgress,
      ) async {
        result = await _settingsFlow.restorePreparedRequest(
          l10n: l10n,
          request: request,
          backupRecoveryKey: backupRecoveryKey,
          recoveryKeyAlreadyVerified: backupRecoveryKey != null,
          onProgress: reportProgress,
        );
      });
      if (result != null) {
        await _presentRestoreResult(result!);
      }
    } on StateError catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    }
  }

  Future<String?> _collectValidatedRestoreRecoveryKey({
    required File backupFile,
    required RestorePrecheck precheck,
  }) async {
    final BuildContext context = pageContext;
    String? validationError;
    while (true) {
      if (!context.mounted) {
        return null;
      }
      final String? recoveryKey = await showRestoreRecoveryKeyDialog(
        context,
        precheck: precheck,
        validationError: validationError,
      );
      if (!context.mounted) {
        return null;
      }
      if (recoveryKey == null) {
        return null;
      }
      try {
        await _settingsFlow.verifyRestoreRecoveryKey(backupFile, recoveryKey);
        return recoveryKey;
      } on StateError catch (error) {
        validationError = error.message;
      }
    }
  }

  Future<void> _presentRestoreResult(SettingsRestoreResult result) async {
    final BuildContext context = pageContext;
    if (!context.mounted) {
      return;
    }
    _showFeedback(result.feedback);
    if (result.prompt != null) {
      final bool runPrimary = await showPostRestoreOutcomeDialog(
        context,
        outcome: result.prompt!,
      );
      if (!context.mounted) {
        return;
      }
      if (runPrimary) {
        switch (result.prompt!.primaryAction) {
          case SettingsRestorePrimaryAction.retryVerification:
            await _settingsFlow.retryTrustedUnlock();
          case SettingsRestorePrimaryAction.openSettingsRecovery:
            context.go(AppRouter.settingsRoute);
        }
      } else {
        context.go(AppRouter.homeRoute);
      }
      return;
    }
    switch (result.navigationTarget) {
      case SettingsRestoreNavigationTarget.home:
        context.go(AppRouter.homeRoute);
      case SettingsRestoreNavigationTarget.settings:
        context.go(AppRouter.settingsRoute);
      case null:
        break;
    }
  }

  Future<void> _retryTrustedUnlock() async {
    await _settingsFlow.retryTrustedUnlock();
  }

  Future<void> _applyUnlockMode(AppUnlockMode mode) async {
    final AppLocalizations l10n = pageContext.l10n;
    _showFeedback(await _settingsFlow.applyUnlockMode(l10n, mode));
  }

  Future<void> _rotateRecoveryKey() async {
    final BuildContext context = pageContext;
    if (!context.mounted) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showRotateRecoveryKeyDialog(context);
    if (!confirmed) {
      return;
    }
    final SettingsRecoveryKeyResult result = await _settingsFlow
        .rotateRecoveryKey(l10n);
    if (!context.mounted) {
      return;
    }
    _showFeedback(result.feedback);
    await showRecoveryKeySaveDialog(
      context,
      title: l10n.settingsRecoveryKeySaveNewDialogTitle,
      recoveryKey: result.recoveryKey,
    );
  }

  Future<void> _runBusy(
    Future<void> Function() action, {
    String? message,
  }) async {
    final AppLocalizations l10n = pageContext.l10n;
    updatePageState(() {
      _busy = true;
      _busyMessage = message;
      _busyProgress = null;
    });
    try {
      await action();
    } catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    } finally {
      if (isMounted) {
        updatePageState(() {
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
    final AppLocalizations l10n = pageContext.l10n;
    void reportProgress(BackupTaskProgress progress) {
      if (!isMounted) {
        return;
      }
      updatePageState(() {
        _busyMessage = settingsBackupTaskProgressLabel(l10n, progress);
        _busyProgress = progress.fraction;
      });
    }

    updatePageState(() {
      _busy = true;
      _busyMessage = null;
      _busyProgress = null;
    });
    try {
      await action(reportProgress);
    } catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error, l10n: l10n),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    } finally {
      if (isMounted) {
        updatePageState(() {
          _busy = false;
          _busyMessage = null;
          _busyProgress = null;
        });
      }
    }
  }

  Future<void> _recordBackupPersistResult(
    BackupPersistResult result, {
    required BackupStatusAction action,
    required String Function(String savedPath) onSuccess,
    String Function(String message)? inspectFailedMessage,
    String? driveAccountLabel,
  }) async {
    _showFeedback(
      await _settingsFlow.recordBackupPersistResult(
        l10n: pageContext.l10n,
        result: result,
        action: action,
        onSuccess: onSuccess,
        inspectFailedMessage: inspectFailedMessage,
        driveAccountLabel: driveAccountLabel,
      ),
    );
  }

  void _showFeedback(SettingsFlowFeedback? feedback) {
    showSettingsFlowFeedback(pageContext, feedback);
  }
}
