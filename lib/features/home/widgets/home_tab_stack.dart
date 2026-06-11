import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/state/app_session_state.dart';
import '../state/home_state.dart';
import 'calendar/calendar_pane.dart';
import 'home_timeline_pane.dart';
import 'overview_pane.dart';
import 'tags_pane.dart';

/// 以 IndexedStack 保留四個首頁分頁狀態，避免切換時重建。
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
