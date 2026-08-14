import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'calendar/calendar_pane.dart';
import 'home_timeline_pane.dart';
import 'overview_pane.dart';
import 'people_pane.dart';
import 'tags_pane.dart';

class HomeTabStack extends ConsumerStatefulWidget {
  const HomeTabStack({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  ConsumerState<HomeTabStack> createState() => _HomeTabStackState();
}

class _HomeTabStackState extends ConsumerState<HomeTabStack> {
  final Set<HomeTab> _visitedTabs = <HomeTab>{HomeTab.home};

  Widget _paneFor(HomeTab tab) {
    if (!_visitedTabs.contains(tab)) {
      return const SizedBox.shrink();
    }
    return switch (tab) {
      HomeTab.home => HomeTimelinePane(sessionState: widget.sessionState),
      HomeTab.calendar => CalendarPane(sessionState: widget.sessionState),
      HomeTab.tags => TagsManagePane(sessionState: widget.sessionState),
      HomeTab.people => PeoplePane(sessionState: widget.sessionState),
      HomeTab.overview => OverviewPane(sessionState: widget.sessionState),
    };
  }

  @override
  Widget build(BuildContext context) {
    final HomeTab activeTab = ref.watch(homeTabProvider);
    _visitedTabs.add(activeTab);

    return IndexedStack(
      index: activeTab.index,
      children: HomeTab.values.map(_paneFor).toList(growable: false),
    );
  }
}
