import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/home/home_browse_state.dart';
import 'calendar/calendar_pane.dart';
import 'home_timeline_pane.dart';
import 'overview_pane.dart';
import 'tags_pane.dart';

class HomeTabStack extends ConsumerWidget {
  const HomeTabStack({required this.sessionState, super.key});

  final AppSessionState sessionState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeTab activeTab = ref.watch(homeTabProvider);

    return IndexedStack(
      index: activeTab.index,
      children: <Widget>[
        HomeTimelinePane(sessionState: sessionState),
        CalendarPane(sessionState: sessionState),
        OverviewPane(sessionState: sessionState),
        TagsManagePane(sessionState: sessionState),
      ],
    );
  }
}
