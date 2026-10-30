import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'package:quill_diary/application/onboarding/onboarding_intro.dart';
import 'package:quill_diary/application/onboarding/onboarding_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_actions.dart';
import 'package:quill_diary/presentation/home/home_layout.dart';
import 'package:quill_diary/presentation/home/widgets/home_circle_action_button.dart';
import 'package:quill_diary/presentation/home/widgets/home_shared_widgets.dart';
import 'package:quill_diary/presentation/home/widgets/home_tab_stack.dart';
import 'package:quill_diary/presentation/onboarding/first_launch_home_pane.dart';
import 'package:quill_diary/presentation/onboarding/onboarding_intro_dialog.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _openingWritingFlow = false;
  Future<void> _chooseWritingMode() async {
    if (_openingWritingFlow) return;
    _openingWritingFlow = true;
    try {
      final route = await showAppDialog<String>(
        context: context,
        builder: (dialogContext) => AppDialogShell(
          title: context.l10n.homeTooltipNewEntry,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: Text(context.l10n.chatDiaryWriteDirectly),
                onTap: () =>
                    Navigator.pop(dialogContext, AppRoutes.editorRoute),
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(context.l10n.chatDiaryWriteWithChat),
                onTap: () => Navigator.pop(dialogContext, 'chat'),
              ),
            ],
          ),
        ),
      );
      if (route != null && mounted) {
        if (route == 'chat') {
          await startChatDiary(context, ref);
        } else {
          unawaited(context.push<void>(route));
        }
      }
    } finally {
      _openingWritingFlow = false;
    }
  }

  bool _introFlowInFlight = false;
  bool _introFlowDone = false;

  Future<void> _maybeStartFirstLaunch(AppSessionState sessionState) async {
    if (_introFlowInFlight || _introFlowDone) {
      return;
    }
    if (!isAwaitingVaultSetup(sessionState)) {
      return;
    }
    _introFlowInFlight = true;

    try {
      await ref
          .read(personalizationPreferencesProvider.notifier)
          .seedDeviceLocaleIfUnset(
            WidgetsBinding.instance.platformDispatcher.locale,
          );
      if (!mounted) {
        return;
      }

      final AppSessionState latest = await ref.read(
        effectiveAppSessionProvider.future,
      );
      if (!mounted) {
        return;
      }
      if (!isAwaitingVaultSetup(latest)) {
        setState(() => _introFlowDone = true);
        return;
      }

      final int version = await ref.read(onboardingIntroVersionProvider.future);
      if (!mounted) {
        return;
      }
      if (!shouldShowOnboardingIntro(
        sessionState: latest,
        storedVersion: version,
      )) {
        setState(() => _introFlowDone = true);
        return;
      }

      await showOnboardingIntroDialog(context);
      if (mounted) {
        setState(() => _introFlowDone = true);
      }
    } catch (_) {
      // 保留閘門；待後續狀態更新重建時重試。
    } finally {
      _introFlowInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(
      effectiveAppSessionProvider,
    );

    return sessionAsync.when(
      data: (AppSessionState sessionState) {
        final bool isFirstLaunch = isAwaitingVaultSetup(sessionState);
        if (isFirstLaunch && !_introFlowInFlight && !_introFlowDone) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_maybeStartFirstLaunch(sessionState));
          });
        }
        final bool canCreate =
            sessionState.isUnlocked && sessionState.session != null;
        final HomeEntrySelectionState selection = ref.watch(
          homeEntrySelectionProvider,
        );
        final HomeTab activeTab = ref.watch(homeTabProvider);
        final bool showFab =
            !isFirstLaunch && activeTab == HomeTab.home && !selection.isActive;
        final bool snackBarLifted =
            ref.watch(appFeedbackVisibilityCountProvider) > 0;
        final double addButtonBottom =
            HomeLayout.bottomActionsInsetFor(snackBarVisible: snackBarLifted) +
            HomeLayout.bodyPadding.bottom;

        return PopScope(
          canPop: !selection.isActive,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop && selection.isActive) {
              ref.read(homeEntrySelectionProvider.notifier).clear();
            }
          },
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(76),
              child: HomeHeader(
                showTabs: !isFirstLaunch,
                settingsEnabled: !isFirstLaunch || _introFlowDone,
              ),
            ),
            body: isFirstLaunch
                ? SafeArea(
                    top: false,
                    child: _introFlowDone
                        ? const FirstLaunchHomePane()
                        : const AppLoadingState(
                            layout: AppLoadingStateLayout.page,
                          ),
                  )
                : Stack(
                    children: <Widget>[
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            HomeLayout.bodyHorizontal,
                            HomeLayout.bodyPadding.top,
                            0,
                            HomeLayout.bodyPadding.bottom,
                          ),
                          child: HomeTabStack(sessionState: sessionState),
                        ),
                      ),
                      if (showFab)
                        AnimatedPositioned(
                          duration: HomeLayout.bottomChromeAnimationDuration,
                          curve: HomeLayout.bottomChromeAnimationCurve,
                          right: HomeLayout.circleActionHorizontalInset,
                          bottom: addButtonBottom,
                          child: SafeArea(
                            top: false,
                            child: HomeCircleActionButton(
                              tooltip: context.l10n.homeTooltipNewEntry,
                              icon: Icons.add_rounded,
                              onPressed: canCreate
                                  ? () => unawaited(_chooseWritingMode())
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: AppLoadingState(layout: AppLoadingStateLayout.page),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AppStateCard(
            icon: Icons.error_outline_rounded,
            title: context.l10n.commonReadFailureTitle,
            message: userFacingErrorMessage(error, l10n: context.l10n),
          ),
        ),
      ),
    );
  }
}

class HomeHeader extends ConsumerStatefulWidget {
  const HomeHeader({
    this.showTabs = true,
    this.settingsEnabled = true,
    super.key,
  });

  final bool showTabs;
  final bool settingsEnabled;

  @override
  ConsumerState<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends ConsumerState<HomeHeader> {
  final Map<HomeTab, GlobalKey> _tabKeys = <HomeTab, GlobalKey>{
    for (final HomeTab tab in HomeTab.values) tab: GlobalKey(),
  };
  HomeTab? _lastActiveTab;

  void _selectTab(WidgetRef ref, HomeTab tab) {
    ref.read(homeEntrySelectionProvider.notifier).clear();
    ref.read(homeTabProvider.notifier).set(tab);
  }

  @override
  Widget build(BuildContext context) {
    final bool showTabs = widget.showTabs;
    final HomeTab activeTab = ref.watch(homeTabProvider);
    if (showTabs && _lastActiveTab != activeTab) {
      _lastActiveTab = activeTab;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final BuildContext? tabContext = _tabKeys[activeTab]?.currentContext;
        if (mounted && tabContext != null) {
          unawaited(
            Scrollable.ensureVisible(
              tabContext,
              alignment: 0.5,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
            ),
          );
        }
      });
    }

    (String, IconData) tabVisual(HomeTab tab) => switch (tab) {
      HomeTab.home => (context.l10n.homeNavHome, Icons.home_rounded),
      HomeTab.calendar => (
        context.l10n.homeNavCalendar,
        Icons.calendar_month_rounded,
      ),
      HomeTab.tags => (context.l10n.homeNavTags, Icons.sell_rounded),
      HomeTab.people => (context.l10n.homeNavPeople, Icons.people_alt_rounded),
      HomeTab.overview => (
        context.l10n.homeNavOverview,
        Icons.insights_rounded,
      ),
    };

    final bool showTabLabels =
        MediaQuery.sizeOf(context).width >= HomeLayout.tabWideBreakpoint;

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 76,
      titleSpacing: 0,
      title: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: <Widget>[
              if (showTabs)
                Expanded(
                  child: SizedBox(
                    height: HomeLayout.searchRowControlHeight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          for (
                            int index = 0;
                            index < HomeTab.values.length;
                            index++
                          ) ...<Widget>[
                            if (index > 0) const SizedBox(width: 5),
                            KeyedSubtree(
                              key: _tabKeys[HomeTab.values[index]],
                              child: showTabLabels
                                  ? HomeHeaderTabButton(
                                      label: tabVisual(HomeTab.values[index])
                                          .$1,
                                      icon: tabVisual(HomeTab.values[index]).$2,
                                      active:
                                          activeTab == HomeTab.values[index],
                                      showLabel: true,
                                      onTap: () => _selectTab(
                                        ref,
                                        HomeTab.values[index],
                                      ),
                                    )
                                  : SizedBox(
                                      width: 52,
                                      child: HomeHeaderTabButton(
                                        label: tabVisual(HomeTab.values[index])
                                            .$1,
                                        icon: tabVisual(HomeTab.values[index])
                                            .$2,
                                        active:
                                            activeTab == HomeTab.values[index],
                                        onTap: () => _selectTab(
                                          ref,
                                          HomeTab.values[index],
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 12),
              HomeHeaderIconButton(
                tooltip: context.l10n.homeTooltipSettings,
                icon: Icons.tune_rounded,
                onPressed: widget.settingsEnabled
                    ? () => unawaited(context.push(AppRoutes.settingsRoute))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
