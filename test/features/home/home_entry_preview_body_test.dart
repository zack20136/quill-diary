import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/theme.dart';
import 'package:quill_diary/features/home/widgets/home_entry_preview_body.dart';
import 'package:quill_diary/l10n/l10n.dart';

void main() {
  testWidgets('HomeEntryPreviewBody 依 markdown 順序顯示內容', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        locale: appZhLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 360,
            child: HomeEntryPreviewBody(
              previewMarkdown: '前言\n- [x] 已完成\n- [ ] 任務三\n- [ ] \n- [x] 另一項',
              fallbackText: '',
              textStyle: TextStyle(fontSize: 14),
              maxLines: 5,
              lineSpacing: 8,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Checkbox), findsNWidgets(4));
    expect(find.textContaining('已完成'), findsOneWidget);
    expect(find.textContaining('任務三'), findsOneWidget);
    expect(find.textContaining('另一項'), findsOneWidget);
    expect(find.textContaining('前言'), findsOneWidget);
  });

  testWidgets('HomeEntryPreviewBody 文字剩一行時只顯示第一個任務項目', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        locale: appZhLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 360,
            child: HomeEntryPreviewBody(
              previewMarkdown: '短前言\n- [ ] 564\n- [ ] 545645645',
              fallbackText: '',
              textStyle: TextStyle(fontSize: 14, height: 1.4),
              maxLines: 2,
              lineSpacing: 8,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.textContaining('564'), findsOneWidget);
    expect(find.textContaining('545645645'), findsNothing);
  });

  testWidgets('HomeEntryPreviewBody 文字已佔滿最大行數時隱藏任務項目', (
    WidgetTester tester,
  ) async {
    const String bodyText =
        '入間同學第四季第七集超好看 是用音樂劇的表演 整整一整集 畫面 音樂 劇情 都超級用心 這集的真的有讚 莉莉斯之毯';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        locale: appZhLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: HomeEntryPreviewBody(
              previewMarkdown: '$bodyText\n- [ ] 868646',
              fallbackText: '',
              textStyle: const TextStyle(fontSize: 14, height: 1.4),
              maxLines: 3,
              lineSpacing: 8,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Checkbox), findsNothing);
    expect(find.textContaining('868646'), findsNothing);
    expect(find.textContaining('莉莉斯之毯'), findsOneWidget);
    expect(find.textContaining('…'), findsNothing);
  });

  testWidgets('HomeEntryPreviewBody 達到行數預算後不會跳過後續行', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        locale: appZhLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 360,
            child: HomeEntryPreviewBody(
              previewMarkdown:
                  '入間同學第四季第七集超好看 是用音樂劇的表演 整整一整集\n'
                  '- [ ] 564\n'
                  '- [ ] 545645645\n'
                  '45645646456',
              fallbackText: '',
              textStyle: TextStyle(fontSize: 14, height: 1.4),
              maxLines: 3,
              lineSpacing: 8,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.textContaining('564'), findsOneWidget);
    expect(find.textContaining('545645645'), findsNothing);
    expect(find.textContaining('45645646456'), findsNothing);
  });

  testWidgets('HomeEntryPreviewBody 文字足夠時仍顯示任務項目', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        locale: appZhLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 360,
            child: HomeEntryPreviewBody(
              previewMarkdown: '短前言\n- [x] 已完成\n- [ ] 任務三',
              fallbackText: '',
              textStyle: TextStyle(fontSize: 14, height: 1.4),
              maxLines: 3,
              lineSpacing: 8,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.textContaining('短前言'), findsOneWidget);
    expect(find.textContaining('已完成'), findsOneWidget);
    expect(find.textContaining('任務三'), findsOneWidget);
  });
}
