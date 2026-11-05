import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

/// 只標記確實由代號還原的文字，不將其他分支的代號或同名原文視為隱藏。
List<PrivateTextRange> restoredPrivateRanges({
  required String outboundText,
  required String text,
  required Map<String, String> originals,
}) {
  final ranges = <PrivateTextRange>[];
  var sourceOffset = 0;
  var textOffset = 0;
  for (final match in privacyTokenPattern.allMatches(outboundText)) {
    final literal = outboundText.substring(sourceOffset, match.start);
    if (!text.startsWith(literal, textOffset)) return const [];
    textOffset += literal.length;
    final token = match[0]!;
    final original = originals[token];
    if (text.startsWith(token, textOffset)) {
      textOffset += token.length;
    } else if (original != null &&
        original.isNotEmpty &&
        text.startsWith(original, textOffset)) {
      ranges.add(PrivateTextRange(textOffset, textOffset + original.length));
      textOffset += original.length;
    } else {
      return const [];
    }
    sourceOffset = match.end;
  }
  if (text.substring(textOffset) != outboundText.substring(sourceOffset)) {
    return const [];
  }
  return mergePrivateRanges(ranges, text.length);
}
