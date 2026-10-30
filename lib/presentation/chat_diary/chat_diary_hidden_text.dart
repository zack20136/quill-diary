import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/domain/chat_diary/chat_diary_privacy_processor.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';

final RegExp chatDiaryPrivacyTokenPattern = RegExp(r'⟦[PS][0-9A-F]{2,}⟧');

Color chatDiaryHiddenHighlight(ColorScheme colors) =>
    colors.tertiary.withValues(alpha: 0.32);

List<ChatDiaryPrivateRange> chatDiaryPrivacyTokenRanges(String text) => [
  for (final match in chatDiaryPrivacyTokenPattern.allMatches(text))
    ChatDiaryPrivateRange(match.start, match.end),
];

TextSpan chatDiaryHiddenTextSpan({
  required String text,
  required List<ChatDiaryPrivateRange> ranges,
  required Color highlight,
  TextStyle? style,
  List<ChatDiaryPrivateRange> underlineRanges = const [],
}) {
  final highlights = mergePrivateRanges(ranges, text.length);
  final underlines = mergePrivateRanges(underlineRanges, text.length);
  final boundaries = <int>{
    0,
    text.length,
    for (final range in highlights) ...[range.start, range.end],
    for (final range in underlines) ...[range.start, range.end],
  }.toList()..sort();
  return TextSpan(
    style: style,
    children: [
      for (var i = 0; i < boundaries.length - 1; i++)
        TextSpan(
          text: text.substring(boundaries[i], boundaries[i + 1]),
          style: TextStyle(
            backgroundColor:
                highlights.any(
                  (range) =>
                      range.start <= boundaries[i] &&
                      range.end >= boundaries[i + 1],
                )
                ? highlight
                : null,
            decoration:
                underlines.any(
                  (range) =>
                      range.start <= boundaries[i] &&
                      range.end >= boundaries[i + 1],
                )
                ? TextDecoration.underline
                : null,
          ),
        ),
    ],
  );
}
