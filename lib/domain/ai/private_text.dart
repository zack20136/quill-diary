/// 聊天與日記整理共用的文字區間。JSON 欄位維持 start／end。
class PrivateTextRange {
  const PrivateTextRange(this.start, this.end);

  final int start;
  final int end;

  Map<String, int> toJson() => {'start': start, 'end': end};

  factory PrivateTextRange.fromJson(Map<String, dynamic> json) =>
      PrivateTextRange(json['start'] as int, json['end'] as int);
}

/// 人物姓名在原文中的區間。JSON 欄位維持 person_id。
class PersonTextRange {
  const PersonTextRange(this.start, this.end, this.personId);

  final int start;
  final int end;
  final String personId;

  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'person_id': personId,
  };

  factory PersonTextRange.fromJson(Map<String, dynamic> json) =>
      PersonTextRange(
        json['start'] as int,
        json['end'] as int,
        json['person_id'] as String,
      );
}

/// 未送出或編輯前的輸入。圖片只存在聊天；空的 imageIds 不寫入。
class AiComposerSnapshot {
  AiComposerSnapshot({
    required this.text,
    required this.ranges,
    required this.imageIds,
  });

  final String text;
  final List<PrivateTextRange> ranges;
  final List<String> imageIds;

  Map<String, Object?> toJson() => {
    'text': text,
    'ranges': ranges.map((range) => range.toJson()).toList(),
    if (imageIds.isNotEmpty) 'image_ids': imageIds,
  };

  factory AiComposerSnapshot.fromJson(
    Map<String, dynamic> json,
  ) => AiComposerSnapshot(
    text: json['text'] as String,
    ranges: (json['ranges'] as List)
        .map(
          (range) =>
              PrivateTextRange.fromJson((range as Map).cast<String, dynamic>()),
        )
        .toList(),
    imageIds: (json['image_ids'] as List? ?? const <String>[]).cast<String>(),
  );
}

List<PrivateTextRange> mergePrivateRanges(
  List<PrivateTextRange> ranges,
  int length,
) {
  final sorted =
      ranges
          .map(
            (range) => PrivateTextRange(
              range.start.clamp(0, length),
              range.end.clamp(0, length),
            ),
          )
          .where((range) => range.start < range.end)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  final result = <PrivateTextRange>[];
  for (final range in sorted) {
    if (result.isNotEmpty && range.start <= result.last.end) {
      final last = result.removeLast();
      result.add(
        PrivateTextRange(
          last.start,
          range.end > last.end ? range.end : last.end,
        ),
      );
    } else {
      result.add(range);
    }
  }
  return result;
}

List<PrivateTextRange> removePrivateRange(
  List<PrivateTextRange> ranges,
  int start,
  int end,
) => [
  for (final range in ranges)
    if (end <= range.start || start >= range.end)
      range
    else ...[
      if (range.start < start) PrivateTextRange(range.start, start),
      if (range.end > end) PrivateTextRange(end, range.end),
    ],
];

/// 編輯碰到私密範圍時，替換的新文字也保持隱藏；不因組字或貼上洩漏。
List<PrivateTextRange> updatePrivateRanges(
  String oldText,
  String newText,
  List<PrivateTextRange> ranges,
) {
  if (oldText == newText) return ranges;
  var start = 0;
  while (start < oldText.length &&
      start < newText.length &&
      oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
    start++;
  }
  var oldEnd = oldText.length;
  var newEnd = newText.length;
  while (oldEnd > start &&
      newEnd > start &&
      oldText.codeUnitAt(oldEnd - 1) == newText.codeUnitAt(newEnd - 1)) {
    oldEnd--;
    newEnd--;
  }
  final delta = newText.length - oldText.length;
  return mergePrivateRanges([
    for (final range in ranges)
      if (oldEnd < range.start)
        PrivateTextRange(range.start + delta, range.end + delta)
      else if (start > range.end)
        range
      else
        PrivateTextRange(
          range.start < start ? range.start : start,
          range.end + delta > newEnd ? range.end + delta : newEnd,
        ),
  ], newText.length);
}
