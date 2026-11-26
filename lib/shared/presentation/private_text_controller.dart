import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/domain/ai/privacy_text_processor.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/people/person_name_matcher.dart';

typedef PrivacyRangeDetector = List<PrivateTextRange> Function(
  String text,
  List<PrivateTextRange> manualRanges,
  List<PrivateTextRange> revealedRanges,
);

/// 聊天與整理的輸入框共用。人名掃描在每次偵測時讀取，開關變更後會跟著更新。
PrivacyRangeDetector privacyRangeDetector(
  PersonNameMatcher? Function() matcher,
) =>
    (text, manual, revealed) => privacyHighlightRanges(
      text,
      manualRanges: manual,
      revealedRanges: revealed,
      nameMatcher: matcher(),
    );

class PrivateTextController extends TextEditingController {
  PrivateTextController({PrivacyRangeDetector? detectRanges})
    : _detectRanges = detectRanges ?? privacyRangeDetector(() => null);
  final PrivacyRangeDetector _detectRanges;
  List<PrivateTextRange> _ranges = [];
  List<PrivateTextRange> _revealed = [];
  List<PrivateTextRange> _highlights = [];
  List<PrivateTextRange> get privateRanges => List.unmodifiable(_ranges);
  List<PrivateTextRange> get revealedRanges => List.unmodifiable(_revealed);
  List<PrivateTextRange> get highlightRanges => List.unmodifiable(_highlights);

  void setDocument(
    String text,
    List<PrivateTextRange> ranges, [
    List<PrivateTextRange> revealed = const [],
  ]) {
    _ranges = mergePrivateRanges(ranges, text.length);
    _revealed = mergePrivateRanges(revealed, text.length);
    _highlights = _detectRanges(text, _ranges, _revealed);
    super.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// 文字或區間有變才重載，避免把游標拉回結尾。
  bool syncDocument(
    String text,
    List<PrivateTextRange> ranges, [
    List<PrivateTextRange> revealed = const [],
  ]) {
    if (this.text == text &&
        samePrivateRanges(_ranges, mergePrivateRanges(ranges, text.length)) &&
        samePrivateRanges(
          _revealed,
          mergePrivateRanges(revealed, text.length),
        )) {
      return false;
    }
    setDocument(text, ranges, revealed);
    return true;
  }

  @override
  set value(TextEditingValue next) {
    if (next.text != text) {
      _ranges = updatePrivateRanges(text, next.text, _ranges);
      _revealed = updatePrivateRanges(text, next.text, _revealed);
      _highlights = _detectRanges(next.text, _ranges, _revealed);
    }
    super.value = next;
  }

  bool _overlapsSelection(PrivateTextRange range) =>
      range.start < selection.end && range.end > selection.start;

  /// 手動區間，或取消後會消失的高亮，都算已隱藏。
  bool get selectionIsHidden {
    if (!selection.isValid || selection.isCollapsed) return false;
    if (_ranges.any(_overlapsSelection)) return true;
    final revealed = mergePrivateRanges([
      ..._revealed,
      PrivateTextRange(selection.start, selection.end),
    ], text.length);
    final without = _detectRanges(text, _ranges, revealed);
    return _highlights.any(
      (range) =>
          _overlapsSelection(range) &&
          !without.any(
            (next) => next.start == range.start && next.end == range.end,
          ),
    );
  }

  void hideSelection() {
    if (!selection.isValid ||
        selection.isCollapsed ||
        value.composing.isValid && !value.composing.isCollapsed) {
      return;
    }
    _revealed = removePrivateRange(_revealed, selection.start, selection.end);
    _ranges = mergePrivateRanges([
      ..._ranges,
      PrivateTextRange(selection.start, selection.end),
    ], text.length);
    refreshHighlights();
  }

  void unhideSelection() {
    if (!selection.isValid || selection.isCollapsed) return;
    _ranges = removePrivateRange(_ranges, selection.start, selection.end);
    _revealed = mergePrivateRanges([
      ..._revealed,
      PrivateTextRange(selection.start, selection.end),
    ], text.length);
    refreshHighlights();
  }

  void refreshHighlights() {
    _highlights = _detectRanges(text, _ranges, _revealed);
    notifyListeners();
  }
}
