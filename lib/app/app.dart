import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:quill_diary/application/session/app_lifecycle_session_bridge.dart';
import 'package:quill_diary/application/session/session_navigation_coordinator.dart';
import 'package:quill_diary/application/settings/billing_providers.dart';
import 'package:quill_diary/application/settings/drive_upload_coordinator.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/infrastructure/drive/drive_upload_job.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/app/theme.dart';

class QuillDiaryApp extends ConsumerStatefulWidget {
  const QuillDiaryApp({super.key});

  @override
  ConsumerState<QuillDiaryApp> createState() => _QuillDiaryAppState();
}

class _QuillDiaryAppState extends ConsumerState<QuillDiaryApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = AppRouter.createRouter();
  late final AppLifecycleSessionBridge _sessionLifecycle =
      AppLifecycleSessionBridge(ref);
  String? _shownFailureJobId;
  bool _showingDriveFailureDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionLifecycle.attach();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(sessionNavigationCoordinatorProvider)
          .bindLocationResolver(() => _router.state.uri.toString());
      unawaited(_refreshDriveUpload(openSettingsIfRequested: true));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionLifecycle.detach();
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshDriveUpload(openSettingsIfRequested: true));
    }
  }

  Future<void> _refreshDriveUpload({
    required bool openSettingsIfRequested,
  }) async {
    final notifier = ref.read(driveUploadCoordinatorProvider.notifier);
    await notifier.refresh();
    if (!mounted) {
      return;
    }
    _maybeShowFailureDialog(ref.read(driveUploadCoordinatorProvider).failure);
    if (!openSettingsIfRequested || !mounted) {
      return;
    }
    final bool openDrive = await notifier.consumeOpenDriveBackup();
    if (!openDrive || !mounted) {
      return;
    }
    if (_currentRoute != AppRouter.settingsRoute) {
      _router.go(AppRouter.settingsRoute);
    }
  }

  void _maybeShowFailureDialog(DriveUploadFailureNotice? failure) {
    if (failure == null ||
        failure.jobId.isEmpty ||
        failure.jobId == _shownFailureJobId ||
        _showingDriveFailureDialog ||
        !mounted) {
      return;
    }
    _shownFailureJobId = failure.jobId;
    _showingDriveFailureDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _showingDriveFailureDialog = false;
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          final AppLocalizations dialogL10n = dialogContext.l10n;
          final String body = failure.message.trim().isNotEmpty
              ? failure.message.trim()
              : dialogL10n.driveUploadAbandonedFailureBody;
          return AlertDialog(
            title: Text(dialogL10n.driveUploadAbandonedFailureTitle),
            content: Text(body),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(dialogL10n.driveUploadAbandonedFailureConfirm),
              ),
            ],
          );
        },
      );
      if (mounted) {
        await ref
            .read(driveUploadCoordinatorProvider.notifier)
            .acknowledgeFailure(failure.jobId);
      }
      _showingDriveFailureDialog = false;
    });
  }

  String get _currentRoute => _router.state.uri.toString();

  void _handleSessionRouteTransition(
    SessionNavigationRequest? previous,
    SessionNavigationRequest? next,
  ) {
    if (next == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final String target = sessionNavigationLocation(next);
      if (_currentRoute != target) {
        _router.go(target);
      }
      ref.read(sessionNavigationRequestProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionNavigationRequest?>(
      sessionNavigationRequestProvider,
      _handleSessionRouteTransition,
    );
    ref.listen<DriveUploadState>(driveUploadCoordinatorProvider, (
      DriveUploadState? previous,
      DriveUploadState next,
    ) {
      _maybeShowFailureDialog(next.failure);
    });

    ref.watch(sponsorBillingLifecycleProvider);
    final Locale locale = ref
        .watch(personalizationPreferencesProvider)
        .maybeWhen(
          data: (PersonalizationPreferences value) => value.materialLocale,
          orElse: () => appZhLocale,
        );
    final ThemeMode themeMode = ref
        .watch(personalizationPreferencesProvider)
        .maybeWhen(
          data: (value) => value.materialThemeMode,
          orElse: () => ThemeMode.system,
        );

    return _sessionLifecycle.wrap(
      MaterialApp.router(
        onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          scrollbars: false,
        ),
        theme: buildAppTheme(brightness: Brightness.light),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: themeMode,
        locale: locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: _router,
      ),
    );
  }
}
