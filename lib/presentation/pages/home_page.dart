import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../domain/shared/value_objects.dart';
import '../../infrastructure/database/index_database.dart';
import '../state/app_session_state.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSessionState> startup = ref.watch(appStartupProvider);
    final AppSessionState localSessionState = ref.watch(appSessionProvider);
    final AppSessionState sessionState = startup.maybeWhen(
      data: (AppSessionState startupState) {
        return localSessionState.status == AppLockStatus.uninitialized
            ? startupState
            : localSessionState;
      },
      orElse: () => localSessionState,
    );
    final AsyncValue<List<EntryIndexRecord>> entriesAsync =
        ref.watch(timelineEntriesProvider);
    final AsyncValue<List<DateOnly>> datesAsync = ref.watch(monthEntryDatesProvider);
    final AsyncValue recoveryAsync = ref.watch(recoveryMetadataProvider);
    final ThemeData theme = Theme.of(context);
    final DateTime visibleMonth = ref.watch(visibleMonthProvider);
    final DateOnly? selectedDate = ref.watch(selectedDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuillLockDiary'),
        actions: [
          IconButton(
            tooltip: '資料救援與備份',
            onPressed: () => context.push(AppRouter.recoveryRoute),
            icon: const Icon(Icons.security_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRouter.editorRoute),
        icon: const Icon(Icons.edit_note),
        label: const Text('寫日記'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (startup.isLoading) const LinearProgressIndicator(minHeight: 2),
          Text('本地加密 Markdown 日記', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Timeline、搜尋、日曆、Recovery 與備份都建立在同一個本機加密 vault。',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session: ${sessionState.status.name}', style: theme.textTheme.labelLarge),
                if (sessionState.message != null) ...[
                  const SizedBox(height: 4),
                  Text(sessionState.message!),
                ],
                if (sessionState.status == AppLockStatus.locked) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => ref
                        .read(appSessionProvider.notifier)
                        .unlock(ref.read(unlockAppUseCaseProvider)),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('解鎖'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          recoveryAsync.when(
            data: (metadata) {
              if (metadata != null) {
                return const SizedBox.shrink();
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('先建立 Recovery Key', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text('建立後才能開始寫入真正的加密資料，也能啟用後續備份與救援。'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.push(AppRouter.recoveryRoute),
                        child: const Text('前往設定'),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              hintText: '搜尋標題、摘要或標籤',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (String value) {
              ref.read(timelineSearchQueryProvider.notifier).update(value);
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: datesAsync.when(
                data: (List<DateOnly> dates) {
                  final Set<String> eventDates =
                      dates.map((DateOnly item) => item.value).toSet();
                  return TableCalendar<EntryIndexRecord>(
                    firstDay: DateTime(2020),
                    lastDay: DateTime(2100),
                    focusedDay: visibleMonth,
                    selectedDayPredicate: (DateTime day) =>
                        selectedDate?.value == DateOnly.fromDateTime(day).value,
                    onPageChanged: (DateTime focusedDay) {
                      ref.read(visibleMonthProvider.notifier).set(
                            DateTime(focusedDay.year, focusedDay.month),
                          );
                    },
                    onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
                      ref.read(visibleMonthProvider.notifier).set(
                            DateTime(focusedDay.year, focusedDay.month),
                          );
                      final DateOnly normalized = DateOnly.fromDateTime(selectedDay);
                      ref.read(selectedDateProvider.notifier).set(
                            selectedDate?.value == normalized.value ? null : normalized,
                          );
                    },
                    eventLoader: (DateTime day) {
                      return eventDates.contains(DateOnly.fromDateTime(day).value)
                          ? const <EntryIndexRecord>[]
                          : const <EntryIndexRecord>[];
                    },
                  );
                },
                loading: () => const SizedBox(
                  height: 96,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object error, StackTrace stackTrace) =>
                    Text('日曆載入失敗：$error'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                selectedDate == null ? '最近日記' : '選取日期：${selectedDate.value}',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              if (selectedDate != null)
                TextButton(
                  onPressed: () => ref.read(selectedDateProvider.notifier).set(null),
                  child: const Text('清除'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          entriesAsync.when(
            data: (List<EntryIndexRecord> entries) {
              if (entries.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.auto_stories_outlined, size: 40),
                        const SizedBox(height: 12),
                        Text('還沒有符合條件的日記', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        const Text('先完成 Recovery Key 設定，然後寫下第一篇日記。'),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: entries
                    .map(
                      (EntryIndexRecord entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: ListTile(
                            onTap: () => context.push('/editor/${entry.id}'),
                            title: Text(entry.title ?? entry.previewText),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(entry.previewText),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _MetaChip(label: entry.date.value),
                                    if (entry.mood != null) _MetaChip(label: entry.mood!),
                                    if (entry.attachmentCount > 0)
                                      _MetaChip(label: '${entry.attachmentCount} 個附件'),
                                    ...entry.tags.take(3).map((String tag) => _MetaChip(label: tag)),
                                  ],
                                ),
                              ],
                            ),
                            trailing: entry.isDeleted
                                ? const Icon(Icons.delete_outline)
                                : const Icon(Icons.chevron_right),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Timeline 載入失敗：$error'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}
