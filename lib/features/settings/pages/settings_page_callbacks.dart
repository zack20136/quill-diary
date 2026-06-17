// ignore_for_file: invalid_use_of_protected_member

part of 'settings_page.dart';

extension _SettingsPageCallbacks on _SettingsPageState {
  Future<void> _openLegalLink(String url) async {
    final bool opened = await launchExternalUrl(url);
    if (!mounted || opened) {
      return;
    }
    _showFeedback(
      SettingsFlowFeedback(
        context.l10n.legalExternalLinkUnavailableMessage,
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
            onTap: () => unawaited(
              _openLegalLink(AppIdentifiers.thirdPartyNoticesUrl),
            ),
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
      future: _settingsFlow.hasTrustedDeviceAccess(),
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

  Future<bool> _confirmDeleteBackup({
    required String title,
    required String body,
  }) {
    return showSettingsDeleteBackupDialog(
      context: context,
      title: title,
      body: body,
    );
  }

  Future<LocalBackupFile?> _pickLocalBackup(List<LocalBackupFile> backups) async {
    final AppLocalizations l10n = context.l10n;
    if (backups.isEmpty) {
      _showFeedback(SettingsFlowFeedback(l10n.settingsLocalBackupNoBackups));
      return null;
    }
    if (!mounted) {
      return null;
    }
    final Map<String, LocalBackupFile> backupsById = <String, LocalBackupFile>{
      for (final LocalBackupFile backup in backups) backup.path: backup,
    };
    final BackupPickListItem? picked = await showSettingsBackupPickerDialog(
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
                await ref.read(settingsActionsProvider).deleteAppLocalBackup(
                  backup,
                );
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
    final AppLocalizations l10n = context.l10n;
    if (backups.isEmpty) {
      _showFeedback(SettingsFlowFeedback(l10n.settingsDriveBackupNoBackups));
      return null;
    }
    if (!mounted) {
      return null;
    }
    final Map<String, DriveBackupFile> backupsById = <String, DriveBackupFile>{
      for (final DriveBackupFile backup in backups) backup.id: backup,
    };
    final BackupPickListItem? picked = await showSettingsBackupPickerDialog(
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
              createdAtLabel: formatDriveBackupTime(l10n, backup.createdAt),
              fileName: backup.name,
              sizeLabel: backup.sizeBytes == null
                  ? null
                  : _formatBytes(backup.sizeBytes!),
              onDelete: () async {
                await ref.read(settingsActionsProvider).deleteDriveBackup(backup);
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

  Future<void> _importDocuments() async {
    _showFeedback(await _settingsFlow.importDocuments(context.l10n));
  }

  Future<void> _exportMarkdown() async {
    _showFeedback(await _settingsFlow.exportMarkdown(context.l10n));
  }

  Future<void> _createRecoveryKey() async {
    final String recoveryKey = await _settingsFlow.createRecoveryKey(context.l10n);
    if (!mounted) {
      return;
    }
    await showRecoveryKeySaveDialog(
      context,
      title: context.l10n.settingsRecoveryKeySaveDialogTitle,
      recoveryKey: recoveryKey,
    );
  }

  Future<void> _createLocalBackup(
    BackupTaskProgressListener reportProgress,
  ) async {
    final BackupPersistResult result = await _settingsFlow.createLocalBackup(
      onProgress: reportProgress,
    );
    _showBackupPersistResult(
      result,
      onSuccess: (String path) =>
          context.l10n.settingsLocalBackupBackupSuccessInApp(path),
    );
  }

  Future<void> _exportLocalBackup(
    BackupTaskProgressListener reportProgress,
  ) async {
    final BackupPersistResult result = await _settingsFlow.exportLocalBackup(
      l10n: context.l10n,
      onProgress: reportProgress,
    );
    _showBackupPersistResult(
      result,
      onSuccess: (String path) =>
          context.l10n.settingsLocalBackupBackupExportSuccess(path),
    );
  }

  Future<void> _uploadDriveBackup(
    BackupTaskProgressListener reportProgress,
  ) async {
    final BackupPersistResult result = await _settingsFlow.uploadDriveBackup(
      onProgress: reportProgress,
    );
    _showBackupPersistResult(
      result,
      onSuccess: (String path) =>
          context.l10n.settingsDriveBackupUploadSuccess(path),
      inspectFailedMessage: (String message) =>
          context.l10n.settingsDriveBackupBackupInspectFailed(message),
    );
  }

  Future<void> _runRestoreFromAppLocalBackup() async {
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
          userFacingErrorMessage(error),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    }
  }

  Future<void> _rebuildIndex() async {
    final SettingsRebuildIndexResult result = await _settingsFlow.rebuildIndex(
      context.l10n,
    );
    if (!mounted) {
      return;
    }
    setState(() => _lastIndexRebuildReport = result.report);
    _showFeedback(result.feedback);
  }

  String _formatLocalBackupTime(LocalBackupFile backup) {
    return DisplayFormat.formatDateTime(context.l10n, backup.createdAt);
  }

  String _formatBytes(int bytes) => DisplayFormat.formatBytesForDisplay(bytes);

  Future<void> _runRestoreFromLocalBackup() async {
    try {
      final PreparedRestoreRequest? request =
          await _settingsFlow.prepareExternalRestore();
      if (request == null) {
        return;
      }
      await _restorePreparedRequest(request);
    } catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    }
  }

  Future<void> _runRestoreFromGoogleDrive() async {
    File? tempBackup;
    String? driveBackupName;
    try {
      final List<DriveBackupFile> backups = await _settingsFlow.listDriveBackups();
      final DriveBackupFile? backup = await _pickDriveBackup(backups);
      if (backup == null) {
        return;
      }
      driveBackupName = backup.name;
      await _runWithBackupProgress((BackupTaskProgressListener reportProgress) async {
        tempBackup = await _settingsFlow.downloadDriveBackupToTempFile(
          backup,
          onProgress: reportProgress,
        );
      });
      if (tempBackup == null) {
        return;
      }
      final PreparedRestoreRequest request = await _settingsFlow.prepareRestoreFile(
        tempBackup!,
        driveBackupName: driveBackupName,
        tempFileToDelete: tempBackup,
      );
      await _restorePreparedRequest(request);
    } catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    } finally {
      if (tempBackup != null && tempBackup!.existsSync()) {
        await tempBackup!.delete();
      }
    }
  }

  Future<void> _linkGoogleDrive() async {
    _showFeedback(await _settingsFlow.linkGoogleDrive(context.l10n));
  }

  Future<void> _switchGoogleDrive() async {
    _showFeedback(await _settingsFlow.switchGoogleDrive(context.l10n));
  }

  Future<void> _disconnectGoogleDrive() async {
    if (!mounted) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showDisconnectDriveDialog(context);
    if (!confirmed) {
      return;
    }
    await _runBusy(() async {
      _showFeedback(await _settingsFlow.disconnectGoogleDrive(l10n));
    }, message: l10n.settingsIndexDisconnectDriveProgress);
  }

  Future<void> _restorePreparedRequest(PreparedRestoreRequest request) async {
    try {
      final RestoreBackupFlow flow = RestoreBackupFlow(ref);
      final RestorePreparedContext? prepared = await flow.prepare(
        context: context,
        backupFile: request.backupFile,
        precheck: request.precheck,
        driveBackupName: request.driveBackupName,
        confirm: (RestorePrecheck precheck, {String? driveBackupName}) =>
            showRestoreConfirmDialog(
              context,
              precheck,
              driveBackupName: driveBackupName,
            ),
      );
      if (prepared == null) {
        return;
      }
      await _runWithBackupProgress((BackupTaskProgressListener reportProgress) async {
        final AppSessionState sessionState = await flow.executeRestoreAndFinishSession(
          backupFile: request.backupFile,
          prepared: prepared,
          onProgress: reportProgress,
        );
        await _presentRestoreSuccess(
          sessionState: sessionState,
          prepared: prepared,
          driveBackupName: request.driveBackupName,
        );
      });
    } on StateError catch (error) {
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
    }
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
      _showFeedback(
        SettingsFlowFeedback(
          sessionState.message ?? context.l10n.vaultTransferRestoreUnlockFailed,
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
      return;
    }
    context.go(AppRouter.homeRoute);
    _showFeedback(
      SettingsFlowFeedback(
        driveAwarePostRestoreSnackBarMessage(
          l10n: context.l10n,
          status: sessionState.status,
          sessionMessage: sessionState.message,
          driveBackupName: driveBackupName,
        ),
        tone: SettingsFlowFeedbackTone.success,
      ),
    );
  }

  Future<void> _retryTrustedUnlock() async {
    await _settingsFlow.retryTrustedUnlock();
  }

  Future<void> _applyUnlockMode(AppUnlockMode mode) async {
    _showFeedback(await _settingsFlow.applyUnlockMode(context.l10n, mode));
  }

  Future<void> _rotateRecoveryKey() async {
    if (!mounted) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showRotateRecoveryKeyDialog(context);
    if (!confirmed) {
      return;
    }
    final String recoveryKey = await _settingsFlow.rotateRecoveryKey(l10n);
    if (!mounted) {
      return;
    }
    await showRecoveryKeySaveDialog(
      context,
      title: l10n.settingsRecoveryKeySaveNewDialogTitle,
      recoveryKey: recoveryKey,
    );
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
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
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
      _showFeedback(
        SettingsFlowFeedback(
          userFacingErrorMessage(error),
          tone: SettingsFlowFeedbackTone.error,
        ),
      );
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
    _showFeedback(
      backupPersistFeedback(
        context,
        result,
        onSuccess: onSuccess,
        inspectFailedMessage: inspectFailedMessage,
      ),
    );
  }

  void _showFeedback(SettingsFlowFeedback? feedback) {
    showSettingsFlowFeedback(context, feedback);
  }
}
