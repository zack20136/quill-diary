import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/shared/presentation/private_text_spans.dart';

class PrivateTextController extends TextEditingController {
  List<PrivateTextRange> _ranges = [];
  List<PrivateTextRange> get privateRanges => List.unmodifiable(_ranges);

  void setDocument(String text, List<PrivateTextRange> ranges) {
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
      PrivateTextRange(selection.start, selection.end),
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
    return privateTextSpan(
      text: text,
      ranges: _ranges,
      style: style,
      highlight: privateTextHighlight(Theme.of(context).colorScheme),
      underlineRanges: showComposing
          ? [PrivateTextRange(composing.start, composing.end)]
          : const [],
    );
  }
}
