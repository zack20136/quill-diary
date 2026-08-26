import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:go_router/go_router.dart';

import 'package:quill_diary/app/router.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import '../home_layout.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import '../widgets/home_circle_action_button.dart';
import '../widgets/home_selection_toolbar.dart';
import '../widgets/home_shared_widgets.dart';
import '../widgets/home_tab_stack.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(
      effectiveAppSessionProvider,
    );

    return sessionAsync.when(
      data: (AppSessionState sessionState) {
        final bool canCreate =
            sessionState.isUnlocked && sessionState.session != null;
        final HomeEntrySelectionState selection = ref.watch(
          homeEntrySelectionProvider,
        );
        final HomeTab activeTab = ref.watch(homeTabProvider);
        final bool showFab = activeTab == HomeTab.home && !selection.isActive;
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
            appBar: const PreferredSize(
              preferredSize: Size.fromHeight(76),
              child: HomeHeader(),
            ),
            body: Stack(
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
                            ? () =>
                                  unawaited(context.push(AppRouter.editorRoute))
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: AppLoadingState(layout: AppLoadingStateLayout.page)),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(userFacingErrorMessage(error, l10n: context.l10n)),
        ),
      ),
    );
  }
}

class HomeHeader extends ConsumerStatefulWidget {
  const HomeHeader({super.key});

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
    final HomeTab activeTab = ref.watch(homeTabProvider);
    if (_lastActiveTab != activeTab) {
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
              Expanded(
                child: SizedBox(
                  height: kHomeSearchRowControlHeight,
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
                          SizedBox(
                            key: _tabKeys[HomeTab.values[index]],
                            width: 50,
                            child: HomeHeaderTabButton(
                              label: tabVisual(HomeTab.values[index]).$1,
                              icon: tabVisual(HomeTab.values[index]).$2,
                              active: activeTab == HomeTab.values[index],
                              onTap: () =>
                                  _selectTab(ref, HomeTab.values[index]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              HomeHeaderIconButton(
                tooltip: context.l10n.homeTooltipSettings,
                icon: Icons.tune_rounded,
                onPressed: () =>
                    unawaited(context.push(AppRouter.settingsRoute)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
