import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'person_mention_query.dart';

final class PersonMentionReplacementTarget {
  const PersonMentionReplacementTarget({
    required this.controller,
    required this.mention,
    required this.expectedText,
  });

  final TextEditingController controller;
  final ActivePersonMentionQuery mention;
  final String expectedText;
}

/// 編輯器 `@` 人物建議的共用狀態；由 [EditorPage] 持有並綁定各文字欄位。
final class EditorPersonMentionController extends ChangeNotifier {
  TextEditingController? _activeController;
  ActivePersonMentionQuery? _mention;
  int _highlightIndex = 0;
  bool _suppressSync = false;

  ActivePersonMentionQuery? get mention => _mention;

  int get highlightIndex => _highlightIndex;

  bool get isActive => _mention != null;

  String get query => _mention?.query ?? '';

  bool isBoundTo(TextEditingController controller) =>
      identical(_activeController, controller);

  void bind(TextEditingController controller) {
    if (identical(_activeController, controller)) {
      syncFromActiveController();
      return;
    }
    _detach();
    _activeController = controller;
    controller.addListener(syncFromActiveController);
    syncFromActiveController();
  }

  void syncFromActiveController() {
    if (_suppressSync) {
      return;
    }
    final TextEditingController? controller = _activeController;
    if (controller == null) {
      _clearMention();
      return;
    }
    if (controller.value.composing.isValid) {
      // 組字中略過 sync，保留現有建議列，避免繁中 IME 閃爍。
      return;
    }
    final TextSelection selection = controller.selection;
    final int cursor = selection.isValid
        ? selection.baseOffset
        : controller.text.length;
    final ActivePersonMentionQuery? next = findActivePersonMentionQuery(
      text: controller.text,
      cursor: cursor,
    );
    if (next == null) {
      _clearMention();
      return;
    }
    final bool unchanged =
        _mention?.atIndex == next.atIndex && _mention?.query == next.query;
    if (unchanged) {
      return;
    }
    _mention = next;
    _highlightIndex = 0;
    notifyListeners();
  }

  void dismiss() {
    _clearMention();
  }

  /// 以指定名稱取代 `@查詢`；成功時回傳 `true`。
  bool applyMentionLabel(String mentionLabel) {
    final TextEditingController? controller = _activeController;
    final ActivePersonMentionQuery? mention = _mention;
    if (controller == null || mention == null) {
      return false;
    }
    final ({String text, int cursor}) result = replacePersonMentionWithName(
      text: controller.text,
      mention: mention,
      mentionLabel: mentionLabel,
    );
    _suppressSync = true;
    controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursor),
      composing: TextRange.empty,
    );
    _suppressSync = false;
    _clearMention();
    return true;
  }

  PersonMentionReplacementTarget? captureReplacementTarget() {
    final TextEditingController? controller = _activeController;
    final ActivePersonMentionQuery? mention = _mention;
    if (controller == null || mention == null) {
      return null;
    }
    return PersonMentionReplacementTarget(
      controller: controller,
      mention: mention,
      expectedText: controller.text.substring(
        mention.atIndex,
        mention.endIndex,
      ),
    );
  }

  bool applyMentionLabelToTarget(
    PersonMentionReplacementTarget target,
    String mentionLabel,
  ) {
    final String text = target.controller.text;
    if (target.mention.atIndex < 0 ||
        target.mention.endIndex > text.length ||
        text.substring(target.mention.atIndex, target.mention.endIndex) !=
            target.expectedText) {
      return false;
    }
    final ({String text, int cursor}) result = replacePersonMentionWithName(
      text: text,
      mention: target.mention,
      mentionLabel: mentionLabel,
    );
    target.controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursor),
      composing: TextRange.empty,
    );
    dismiss();
    return true;
  }

  void moveHighlight(int delta, int suggestionCount) {
    if (!isActive || suggestionCount <= 0) {
      return;
    }
    final int next = (_highlightIndex + delta) % suggestionCount;
    final int normalized = next < 0 ? next + suggestionCount : next;
    if (normalized == _highlightIndex) {
      return;
    }
    _highlightIndex = normalized;
    notifyListeners();
  }

  /// 處理方向鍵、Enter、Escape；Enter 選取時回傳 `true`（由呼叫端套用選項）。
  ({KeyEventResult result, bool shouldApplySelection}) handleKeyEvent(
    KeyEvent event, {
    required int suggestionCount,
  }) {
    if (!isActive || event is! KeyDownEvent) {
      return (result: KeyEventResult.ignored, shouldApplySelection: false);
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      dismiss();
      return (result: KeyEventResult.handled, shouldApplySelection: false);
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      moveHighlight(1, suggestionCount);
      return (result: KeyEventResult.handled, shouldApplySelection: false);
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      moveHighlight(-1, suggestionCount);
      return (result: KeyEventResult.handled, shouldApplySelection: false);
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (suggestionCount == 0) {
        return (result: KeyEventResult.ignored, shouldApplySelection: false);
      }
      return (result: KeyEventResult.handled, shouldApplySelection: true);
    }
    return (result: KeyEventResult.ignored, shouldApplySelection: false);
  }

  void _detach() {
    _activeController?.removeListener(syncFromActiveController);
    _activeController = null;
  }

  void _clearMention() {
    if (_mention == null && _highlightIndex == 0) {
      return;
    }
    _mention = null;
    _highlightIndex = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }
}
