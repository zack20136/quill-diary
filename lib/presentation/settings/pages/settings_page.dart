import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/app/app_identifiers.dart';
import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/session_messages.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/settings/drive_upload_coordinator.dart';
import 'package:quill_diary/application/settings/settings_flow_controller.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/application/settings/settings_text.dart';
import 'package:quill_diary/application/settings/vault_transfer_capabilities.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/infrastructure/drive/drive_backup_service.dart';
import 'package:quill_diary/infrastructure/drive/drive_upload_job.dart';
import 'package:quill_diary/infrastructure/drive/google_oauth_config.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/backup_status_store.dart';
import 'package:quill_diary/infrastructure/storage/backup_task_progress.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/infrastructure/storage/vault_maintenance_models.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/infrastructure/storage/vault_transfer_models.dart';
import 'package:quill_diary/infrastructure/storage/vault_archive_io.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/portable_export_confirm.dart';
import 'package:quill_diary/presentation/home/portable_import_confirm.dart';
import 'package:quill_diary/presentation/restore/widgets/post_restore_outcome_dialog.dart';
import 'package:quill_diary/presentation/restore/widgets/restore_recovery_key_dialog.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';
import 'package:quill_diary/shared/utils/external_url.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';

import '../backup/backup_pick_list_item.dart';
import '../settings_capabilities.dart';
import '../widgets/drive_backup_section.dart';
import '../widgets/local_backup_section.dart';
import '../widgets/recovery_key_save_dialog.dart';
import '../widgets/settings_action_dialogs.dart';
import '../widgets/settings_flow_feedback.dart';
import '../widgets/settings_sections.dart';

part 'settings_page_callbacks.dart';
part 'settings_page_components.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({this.initialFocus, super.key});

  final SettingsFocusTarget? initialFocus;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _recoveryKeyInputController =
      TextEditingController();
  final GlobalKey _recoveryKeySectionKey = GlobalKey();
  final GlobalKey _localBackupSectionKey = GlobalKey();
  final FocusNode _recoveryKeyFocusNode = FocusNode();
  final FocusNode _localBackupFocusNode = FocusNode();
  final ScrollController _pageScrollController = ScrollController();
  bool _busy = false;
  bool _showBusyOverlay = true;
  String? _busyMessage;
  double? _busyProgress;
  bool _initialFocusScheduled = false;

  SettingsFlowController get _settingsFlow =>
      ref.read(settingsFlowControllerProvider);

  BuildContext get pageContext => context;

  bool get isMounted => mounted;

  WidgetRef get pageRef => ref;

  @override
  void initState() {
    super.initState();
    // 進設定即可重試成功收尾／停止清理，不單靠 App resumed。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(driveUploadCoordinatorProvider.notifier).refresh());
    });
  }

  void _scheduleInitialFocusIfReady({required bool layoutReady}) {
    final SettingsFocusTarget? focus = widget.initialFocus;
    if (focus == null || _initialFocusScheduled || !layoutReady) {
      return;
    }
    _initialFocusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_focusSection(focus));
    });
  }

  Future<void> _focusSection(
    SettingsFocusTarget focus, {
    int attempt = 0,
  }) async {
    final GlobalKey key = switch (focus) {
      SettingsFocusTarget.recoveryKey => _recoveryKeySectionKey,
      SettingsFocusTarget.externalRestore => _localBackupSectionKey,
    };
    final FocusNode focusNode = switch (focus) {
      SettingsFocusTarget.recoveryKey => _recoveryKeyFocusNode,
      SettingsFocusTarget.externalRestore => _localBackupFocusNode,
    };
    final BuildContext? target = key.currentContext;
    if (target == null && attempt < 5 && mounted) {
      if (_pageScrollController.hasClients) {
        _pageScrollController.jumpTo(
          _pageScrollController.position.maxScrollExtent,
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_focusSection(focus, attempt: attempt + 1));
      });
      return;
    }
    if (target == null || !mounted) {
      return;
    }
    if (focus == SettingsFocusTarget.externalRestore) {
      final bool aligned = _jumpSectionToViewportTop(target);
      // 第一次進頁 maxScrollExtent 常還沒含下方 Drive，多對幾幀才穩。
      if (attempt < 8 && (!aligned || attempt < 3) && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_focusSection(focus, attempt: attempt + 1));
        });
        return;
      }
      focusNode.requestFocus();
      return;
    }
    await Scrollable.ensureVisible(
      target,
      alignment: 0.08,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) {
      return;
    }
    focusNode.requestFocus();
  }

  /// 把區塊頂端對齊 ListView 可視區頂端。
  bool _jumpSectionToViewportTop(BuildContext target) {
    if (!_pageScrollController.hasClients) {
      return false;
    }
    final RenderObject? renderObject = target.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }
    final RenderAbstractViewport? viewport = RenderAbstractViewport.maybeOf(
      renderObject,
    );
    if (viewport == null) {
      return false;
    }
    final ScrollPosition position = _pageScrollController.position;
    final double rawOffset = viewport
        .getOffsetToReveal(renderObject, 0.0)
        .offset;
    final double offset = rawOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - offset).abs() >= 1) {
      _pageScrollController.jumpTo(offset);
    }
    return rawOffset <= position.maxScrollExtent + 1;
  }

  void updatePageState(VoidCallback callback) {
    setState(callback);
  }

  @override
  void dispose() {
    _recoveryKeyInputController.dispose();
    _recoveryKeyFocusNode.dispose();
    _localBackupFocusNode.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(
      effectiveAppSessionProvider,
    );
    final AsyncValue<RecoveryMetadata?> recoveryMetadataAsync = ref.watch(
      recoveryMetadataProvider,
    );
    final AsyncValue<bool> trustedDeviceAccessAsync = ref.watch(
      trustedDeviceAccessProvider,
    );
    final AsyncValue<AppUnlockMode> unlockModeAsync = ref.watch(
      unlockModeProvider,
    );
    final AsyncValue<VaultRepairSummary?> repairSummaryAsync = ref.watch(
      vaultRepairSummaryProvider,
    );
    final AsyncValue<VaultInspectSummary?> inspectSummaryAsync = ref.watch(
      vaultInspectSummaryProvider,
    );
    final AppSessionState? sessionState = sessionAsync.asData?.value;
    final RecoveryMetadata? recoveryMetadata =
        recoveryMetadataAsync.asData?.value;
    final SettingsPageCapabilities pageAccess =
        SettingsPageCapabilities.fromSessionState(
          l10n: l10n,
          sessionState: sessionState,
          hasRecoveryKey: recoveryMetadata != null,
        );
    final VaultTransferCapabilities transferAccess =
        pageAccess.vaultTransferCapabilities;
    _scheduleInitialFocusIfReady(
      layoutReady:
          !sessionAsync.isLoading &&
          !recoveryMetadataAsync.isLoading &&
          !trustedDeviceAccessAsync.isLoading &&
          !unlockModeAsync.isLoading &&
          !repairSummaryAsync.isLoading &&
          !inspectSummaryAsync.isLoading,
    );
    final bool isGoogleDriveConfigured =
        !Platform.isIOS || OAuthConfig.isIosGoogleDriveConfigured;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPageTitle)),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (OverscrollIndicatorNotification notification) {
                notification.disallowIndicator();
                return false;
              },
              child: AppScrollablePageBody(
                controller: _pageScrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: <Widget>[
                  const _SettingsTopNavSection(),
                  const SizedBox(height: 16),
                  Focus(
                    focusNode: _recoveryKeyFocusNode,
                    child: KeyedSubtree(
                      key: _recoveryKeySectionKey,
                      child: _buildSecurityStatusSection(
                        sessionAsync: sessionAsync,
                        recoveryMetadata: recoveryMetadata,
                        pageAccess: pageAccess,
                        trustedDeviceAccessAsync: trustedDeviceAccessAsync,
                        unlockModeAsync: unlockModeAsync,
                        repairSummaryAsync: repairSummaryAsync,
                        inspectSummaryAsync: inspectSummaryAsync,
                      ),
                    ),
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
                                recoveryMetadataAsync.asData?.value != null,
                            changeAllowed: pageAccess.hasUnlockedSession,
                            busy: _busy,
                            unlockMode: unlockMode,
                            onModeSelected: (AppUnlockMode selected) =>
                                _runBusy(() => _applyUnlockMode(selected)),
                          ),
                      loading: () => const AppLoadingState(),
                      error: (Object error, StackTrace _) => AppFeedbackBanner(
                        icon: Icons.error_outline_rounded,
                        message: userFacingErrorMessage(error, l10n: l10n),
                        tone: AppFeedbackTone.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    icon: Icons.swap_horiz_rounded,
                    title: l10n.settingsImportExportSectionTitle,
                    description: transferAccess.canPortableTransfer
                        ? l10n.settingsImportExportSectionDescriptionEnabled
                        : transferAccess.portableTransferDisabledReason ??
                              l10n.vaultTransferNeedsUnlockForPortableTransfer,
                    child: AppActionGroup(
                      actions: <Widget>[
                        AppActionButton(
                          label: l10n.settingsImportExportImportButton,
                          icon: Icons.file_download_outlined,
                          appearance: AppActionButtonAppearance.tonal,
                          fullWidth: true,
                          onPressed:
                              _busy || !transferAccess.canPortableTransfer
                              ? null
                              : _importDocuments,
                        ),
                        AppActionButton(
                          label: l10n.settingsImportExportExportButton,
                          icon: Icons.file_upload_outlined,
                          appearance: AppActionButtonAppearance.primary,
                          fullWidth: true,
                          onPressed:
                              _busy || !transferAccess.canPortableTransfer
                              ? null
                              : _exportMarkdown,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Focus(
                    focusNode: _localBackupFocusNode,
                    child: LocalBackupSection(
                      key: _localBackupSectionKey,
                      access: transferAccess,
                      busy: _busy,
                      onCreate: () =>
                          _runWithBackupProgress(_createLocalBackup),
                      onRestore: _runRestoreFromAppLocalBackup,
                      onExport: () =>
                          _runWithBackupProgress(_exportLocalBackup),
                      onImport: _runRestoreFromLocalBackup,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DriveBackupSection(
                    access: transferAccess,
                    canManageDriveAccount: pageAccess.canManageDriveAccount,
                    isGoogleDriveConfigured: isGoogleDriveConfigured,
                    busy: _busy,
                    onLink: () => _runBusy(
                      _linkGoogleDrive,
                      message: l10n.settingsIndexLinkDriveProgress,
                    ),
                    onSwitchAccount: () => _runBusy(
                      _switchGoogleDrive,
                      message: l10n.settingsIndexSwitchDriveAccountProgress,
                    ),
                    onDisconnect: _disconnectGoogleDrive,
                    onUpload: () => _runWithBackupProgress(_uploadDriveBackup),
                    onRestore: _runRestoreFromGoogleDrive,
                    onCancelUpload: _cancelDriveUpload,
                    onAbandonCancelCleanup: _abandonCancelCleanup,
                  ),
                  const SizedBox(height: 16),
                  _buildLegalSection(context, cs),
                ],
              ),
            ),
            if (_busy && _showBusyOverlay)
              SettingsBlockingProgressOverlay(
                title: l10n.settingsProgressWorkingTitle,
                message: _busyMessage ?? l10n.settingsProgressDefault,
                hint: l10n.settingsProgressKeepAppOpenHint,
                progress: _busyProgress,
              ),
          ],
        ),
      ),
    );
  }
}
