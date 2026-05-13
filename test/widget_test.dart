import 'package:flutter_test/flutter_test.dart';

import 'package:quill_lock_diary/app/app.dart';

void main() {
  testWidgets('app shows QuillLockDiary home shell', (WidgetTester tester) async {
    await tester.pumpWidget(const QuillLockDiaryApp());

    expect(find.text('QuillLockDiary'), findsOneWidget);
    expect(find.text('本地加密 Markdown 日記'), findsOneWidget);
  });
}
