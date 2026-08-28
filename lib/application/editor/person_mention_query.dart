/// 編輯器 `@` 快速選人的作用中查詢。
final class ActivePersonMentionQuery {
  const ActivePersonMentionQuery({required this.atIndex, required this.query});

  /// `@` 在整段文字中的位置。
  final int atIndex;

  /// `@` 之後、游標之前的查詢字串（不含 `@`）。
  final String query;

  int get endIndex => atIndex + 1 + query.length;
}

bool _isMentionAtSign(int codeUnit) {
  return codeUnit == 0x40 || codeUnit == 0xFF20;
}

/// 從游標向前找同一行最後一個可觸發的 `@`／`＠`。
///
/// 不要求前方空白；緊接在任何文字後面也可觸發。
/// query 含 `.`（如 email 網域）時不視為人物提及。
ActivePersonMentionQuery? findActivePersonMentionQuery({
  required String text,
  required int cursor,
  int maxQueryLength = 40,
}) {
  if (cursor < 0 || cursor > text.length) {
    return null;
  }
  int lineStart = cursor;
  while (lineStart > 0 && text.codeUnitAt(lineStart - 1) != 0x0A) {
    lineStart -= 1;
  }

  for (int i = cursor - 1; i >= lineStart; i--) {
    if (!_isMentionAtSign(text.codeUnitAt(i))) {
      continue;
    }
    final String query = text.substring(i + 1, cursor);
    if (query.length > maxQueryLength) {
      return null;
    }
    if (query.contains('\n') || query.contains('.')) {
      return null;
    }
    return ActivePersonMentionQuery(atIndex: i, query: query);
  }
  return null;
}

/// 以指定名稱取代 `@查詢`，不自動加空白。
({String text, int cursor}) replacePersonMentionWithName({
  required String text,
  required ActivePersonMentionQuery mention,
  required String mentionLabel,
}) {
  final String next = text.replaceRange(
    mention.atIndex,
    mention.endIndex,
    mentionLabel,
  );
  return (text: next, cursor: mention.atIndex + mentionLabel.length);
}
