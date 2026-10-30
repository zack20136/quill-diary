import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/domain/chat_diary/chat_diary_privacy_processor.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_hidden_text.dart';

class ChatDiaryPrivateTextController extends TextEditingController {
  List<ChatDiaryPrivateRange> _ranges = [];
  List<ChatDiaryPrivateRange> get privateRanges => List.unmodifiable(_ranges);

  void setDocument(String text, List<ChatDiaryPrivateRange> ranges) {
    _ranges = mergePrivateRanges(ranges, text.length);
    super.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  set value(TextEditingValue next) {
    _ranges = updatePrivateRanges(text, next.text, _ranges);
    super.value = next;
  }

  bool get selectionIsPrivate =>
      selection.isValid &&
      !selection.isCollapsed &&
      _ranges.any((r) => r.start < selection.end && r.end > selection.start);

  void hideSelection() {
    if (!selection.isValid ||
        selection.isCollapsed ||
        value.composing.isValid && !value.composing.isCollapsed) {
      return;
    }
    _ranges = mergePrivateRanges([
      ..._ranges,
      ChatDiaryPrivateRange(selection.start, selection.end),
    ], text.length);
    notifyListeners();
  }

  void unhideSelection() {
    if (!selection.isValid || selection.isCollapsed) return;
    _ranges = removePrivateRange(_ranges, selection.start, selection.end);
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final composing = value.composing;
    final showComposing =
        withComposing && value.isComposingRangeValid && !composing.isCollapsed;
    return chatDiaryHiddenTextSpan(
      text: text,
      ranges: _ranges,
      style: style,
      highlight: chatDiaryHiddenHighlight(Theme.of(context).colorScheme),
      underlineRanges: showComposing
          ? [ChatDiaryPrivateRange(composing.start, composing.end)]
          : const [],
    );
  }
}
