import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';
import 'package:quill_diary/shared/presentation/app_typography.dart';

Color privateTextHighlight(ColorScheme colors) =>
    colors.tertiary.withValues(alpha: 0.32);

/// 高亮若沿用 Inter，中文會落到 Noto 的不同行高，底色就會高低不一。
TextStyle? _spanStyle({required Color? highlight, required bool underline}) {
  if (highlight == null && !underline) return null;
  return TextStyle(
    backgroundColor: highlight,
    decoration: underline ? TextDecoration.underline : null,
    fontFamily: highlight == null ? null : AppTypography.notoSansTcFamily,
    fontFamilyFallback: highlight == null
        ? null
        : const <String>[AppTypography.notoSansTcFamily],
  );
}

List<PrivateTextRange> privacyTokenRanges(String text) => [
  for (final match in privacyTokenPattern.allMatches(text))
    PrivateTextRange(match.start, match.end),
];

TextSpan privateTextSpan({
  required String text,
  required List<PrivateTextRange> ranges,
  required Color highlight,
  TextStyle? style,
  List<PrivateTextRange> underlineRanges = const [],
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
          style: _spanStyle(
            highlight:
                highlights.any(
                  (range) =>
                      range.start <= boundaries[i] &&
                      range.end >= boundaries[i + 1],
                )
                ? highlight
                : null,
            underline: underlines.any(
              (range) =>
                  range.start <= boundaries[i] &&
                  range.end >= boundaries[i + 1],
            ),
          ),
        ),
    ],
  );
}
