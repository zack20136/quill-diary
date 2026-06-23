import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/presentation/page_style.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/utils/user_facing_error.dart';
import '../../session/providers/session_providers.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
import '../home_layout.dart';
import '../providers/home_bottom_chrome_provider.dart';
import '../state/home_state.dart';
import '../widgets/home_circle_action_button.dart';
import '../widgets/home_selection_toolbar.dart';
import '../widgets/home_shared_widgets.dart';
import '../widgets/home_tab_stack.dart';

/// 瀏覽、搜尋與摘要日記內容的主要落地頁。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final bool isSupportedPlatform = ref.watch(supportedPlatformProvider);
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(
      effectiveAppSessionProvider,
    );

    if (!isSupportedPlatform) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(sessionAndroidOnlyMessage(context.l10n))),
      );
    }

    return sessionAsync.when(
      data: (AppSessionState sessionState) {
        final bool canCreate =
            sessionState.isUnlocked && sessionState.session != null;
        final ColorScheme cs = Theme.of(context).colorScheme;
        final HomeEntrySelectionState selection = ref.watch(
          homeEntrySelectionProvider,
        );
        final HomeTab activeTab = ref.watch(homeTabProvider);
        final bool showFab = activeTab == HomeTab.home && !selection.isActive;
        final bool snackBarLifted = homeBottomChromeLifted(ref);
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
            backgroundColor: PageStyle.scaffoldWash(cs),
            appBar: const PreferredSize(
              preferredSize: Size.fromHeight(76),
              child: HomeHeader(),
            ),
            body: Stack(
              children: <Widget>[
                ColoredBox(
                  color: PageStyle.scaffoldWash(cs),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: HomeLayout.bodyPadding,
                      child: HomeTabStack(sessionState: sessionState),
                    ),
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
                            ? () => unawaited(
                                context.push(AppRouter.editorRoute),
                              )
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
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(userFacingErrorMessage(error, l10n: context.l10n)),
        ),
      ),
    );
  }
}

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  void _selectTab(WidgetRef ref, HomeTab tab) {
    ref.read(homeEntrySelectionProvider.notifier).clear();
    ref.read(homeTabProvider.notifier).set(tab);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);
    final HomeTab activeTab = ref.watch(homeTabProvider);

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: pageBackground,
      surfaceTintColor: Colors.transparent,
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
              SizedBox(
                height: kHomeSearchRowControlHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: 50,
                      child: HomeHeaderTabButton(
                        label: context.l10n.homeNavHome,
                        icon: Icons.home_rounded,
                        active: activeTab == HomeTab.home,
                        onTap: () => _selectTab(ref, HomeTab.home),
                      ),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 50,
                      child: HomeHeaderTabButton(
                        label: context.l10n.homeNavCalendar,
                        icon: Icons.calendar_month_rounded,
                        active: activeTab == HomeTab.calendar,
                        onTap: () => _selectTab(ref, HomeTab.calendar),
                      ),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 50,
                      child: HomeHeaderTabButton(
                        label: context.l10n.homeNavTags,
                        icon: Icons.sell_rounded,
                        active: activeTab == HomeTab.tags,
                        onTap: () => _selectTab(ref, HomeTab.tags),
                      ),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 50,
                      child: HomeHeaderTabButton(
                        label: context.l10n.homeNavOverview,
                        icon: Icons.insights_rounded,
                        active: activeTab == HomeTab.overview,
                        onTap: () => _selectTab(ref, HomeTab.overview),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
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
