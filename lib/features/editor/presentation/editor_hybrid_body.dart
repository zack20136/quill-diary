import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../infrastructure/preferences/editor_typography_preferences.dart';
import '../../../l10n/l10n.dart';
import '../../../app/app_colors.dart';
import '../application/editor_body_blocks.dart';
import 'editor_checkbox_block_row.dart';

class EditorHybridBody extends StatefulWidget {
  const EditorHybridBody({
    super.key,
    required this.bodyController,
    required this.typography,
    required this.onBodyChanged,
  });

  final TextEditingController bodyController;
  final EditorTypographyPreferences typography;
  final VoidCallback onBodyChanged;

  @override
  State<EditorHybridBody> createState() => EditorHybridBodyState();
}

class EditorHybridBodyState extends State<EditorHybridBody> {
  List<EditorBodyLine> _lines = <EditorBodyLine>[];
  final Map<String, TextEditingController> _lineControllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _lineFocusNodes = <String, FocusNode>{};
  final FocusNode _plainTextFocusNode = FocusNode();
  String? _focusedLineId;
  String? _syncingFromController;
  String? _pendingFocusLineId;
  bool _committingToBodyController = false;
  bool _hybridMode = false;

  @override
  void initState() {
    super.initState();
    _plainTextFocusNode.addListener(_onPlainTextFocusChanged);
    _reloadFromController();
    widget.bodyController.addListener(_onExternalControllerChanged);
  }

  @override
  void didUpdateWidget(EditorHybridBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bodyController != widget.bodyController) {
      oldWidget.bodyController.removeListener(_onExternalControllerChanged);
      widget.bodyController.addListener(_onExternalControllerChanged);
      _reloadFromController();
    }
  }

  @override
  void dispose() {
    widget.bodyController.removeListener(_onExternalControllerChanged);
    _plainTextFocusNode.removeListener(_onPlainTextFocusChanged);
    _plainTextFocusNode.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _onPlainTextFocusChanged() {
    if (_plainTextFocusNode.hasFocus && _lines.isNotEmpty) {
      _focusedLineId = _lines.first.id;
    }
  }

  void _onExternalControllerChanged() {
    if (_committingToBodyController) {
      return;
    }
    if (widget.bodyController.text == serializeEditorBodyLines(_lines)) {
      return;
    }
    if (_syncingFromController == widget.bodyController.text) {
      return;
    }
    _reloadFromController();
  }

  void _reloadFromController() {
    _lines = ensureEditorBodyLinesForEditing(
      reparseEditorBodyLinesPreservingIds(
        widget.bodyController.text,
        previousLines: _lines,
      ),
    );
    if (editorLinesHaveCheckbox(_lines)) {
      _enterHybridEditing();
      _focusPendingLine();
      return;
    }
    _syncEditingSurfaceMode();
  }

  void _enterHybridEditing() {
    _hybridMode = true;
    _pruneControllers();
    _syncControllersWithLines();
    if (mounted) {
      setState(() {});
    }
  }

  void _writeBodyControllerText(String markdown) {
    if (widget.bodyController.text == markdown) {
      return;
    }
    _committingToBodyController = true;
    _syncingFromController = markdown;
    widget.bodyController.text = markdown;
    _syncingFromController = null;
    _committingToBodyController = false;
  }

  void _requestPlainTextFocus({int? offset}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _plainTextFocusNode.requestFocus();
      if (offset == null) {
        return;
      }
      final int safeOffset = offset.clamp(0, widget.bodyController.text.length);
      widget.bodyController.selection = TextSelection.collapsed(
        offset: safeOffset,
      );
    });
  }

  void _syncEditingSurfaceMode({String? focusLineId, int? plainTextOffset}) {
    if (editorLinesHaveCheckbox(_lines)) {
      _enterHybridEditing();
      if (focusLineId != null) {
        _requestFocusOnLine(focusLineId);
      }
      return;
    }

    if (!_hybridMode) {
      return;
    }

    final String plainMarkdown = collapseEditorBodyToPlainMarkdown(_lines);
    _disposeControllers();
    _lines = plainMarkdown.isEmpty
        ? <EditorBodyLine>[createEmptyTextLine()]
        : parseEditorBodyLines(plainMarkdown);
    _hybridMode = false;
    _focusedLineId = null;
    _pendingFocusLineId = null;
    _writeBodyControllerText(plainMarkdown);
    if (mounted) {
      setState(() {});
    }
    _requestPlainTextFocus(offset: plainTextOffset);
  }

  void _disposeControllers() {
    for (final TextEditingController controller in _lineControllers.values) {
      controller.dispose();
    }
    for (final FocusNode node in _lineFocusNodes.values) {
      node.dispose();
    }
    _lineControllers.clear();
    _lineFocusNodes.clear();
  }

  bool _syncingControllers = false;

  /// 將各 line 編輯器的最新內容寫回 [bodyController]。
  void flushBodyToController() {
    if (!_hybridMode) {
      _lines = ensureEditorBodyLinesForEditing(
        reparseEditorBodyLinesPreservingIds(
          widget.bodyController.text,
          previousLines: _lines,
        ),
      );
      return;
    }
    _commitLines(ensureTrailing: true);
  }

  String _lineText(EditorBodyLine line) {
    return switch (line) {
      EditorTextLine(:final String text) => text,
      EditorCheckboxLine(:final String text) => text,
    };
  }

  TextEditingController _controllerForLine(EditorBodyLine line) {
    final String lineId = line.id;
    return _lineControllers.putIfAbsent(lineId, () {
      final TextEditingController controller = TextEditingController(
        text: _lineText(line),
      );
      if (line is EditorTextLine) {
        controller.addListener(() => _onLineControllerChanged(lineId));
      }
      return controller;
    });
  }

  void _onLineControllerChanged(String lineId) {
    if (_syncingControllers || !mounted) {
      return;
    }
    final TextEditingController? controller = _lineControllers[lineId];
    if (controller == null) {
      return;
    }
    _updateLineText(lineId, controller.text);
  }

  void _pruneControllers() {
    final Set<String> liveIds = _lines
        .map((EditorBodyLine line) => line.id)
        .toSet();
    for (final String id
        in _lineControllers.keys
            .where((String key) => !liveIds.contains(key))
            .toList()) {
      _lineControllers.remove(id)?.dispose();
      _lineFocusNodes.remove(id)?.dispose();
    }
  }

  void _syncControllersWithLines() {
    _syncingControllers = true;
    try {
      for (final EditorBodyLine line in _lines) {
        final TextEditingController controller = _controllerForLine(line);
        final String text = _lineText(line);
        if (controller.text != text) {
          controller.text = text;
        }
        _lineFocusNodes.putIfAbsent(line.id, () {
          final String lineId = line.id;
          if (line is EditorCheckboxLine) {
            return FocusNode(
              onKeyEvent: (FocusNode node, KeyEvent event) {
                return _handleCheckboxKeyEvent(lineId: lineId, event: event);
              },
            )..addListener(() => _onLineFocusChanged(lineId));
          }
          return FocusNode(
            onKeyEvent: (FocusNode node, KeyEvent event) {
              final int? lineIndex = _lineIndexById(lineId);
              if (lineIndex == null) {
                return KeyEventResult.ignored;
              }
              return _handleTextLineKeyEvent(
                lineId: lineId,
                lineIndex: lineIndex,
                event: event,
              );
            },
          )..addListener(() => _onLineFocusChanged(lineId));
        });
      }
    } finally {
      _syncingControllers = false;
    }
  }

  void _onLineFocusChanged(String lineId) {
    if (_lineFocusNodes[lineId]?.hasFocus ?? false) {
      _focusedLineId = lineId;
    }
  }

  void _refreshLinesFromControllers() {
    _lines = _lines.map((EditorBodyLine line) {
      final TextEditingController? controller = _lineControllers[line.id];
      final String text = controller?.text ?? _lineText(line);
      return switch (line) {
        EditorTextLine() => line.copyWith(text: text),
        EditorCheckboxLine() => line.copyWith(text: text),
      };
    }).toList();
  }

  void _commitLines({
    bool ensureTrailing = false,
    bool refreshControllers = true,
  }) {
    if (refreshControllers) {
      _refreshLinesFromControllers();
    }
    if (ensureTrailing) {
      _lines = ensureEditorBodyLinesForEditing(_lines);
    }
    final String markdown = _hybridMode
        ? serializeEditorBodyLines(_lines)
        : collapseEditorBodyToPlainMarkdown(_lines);
    _writeBodyControllerText(markdown);
  }

  void _requestFocusOnLine(String id) {
    _pendingFocusLineId = id;
    _focusPendingLine();
  }

  void _focusPendingLine() {
    final String? id = _pendingFocusLineId;
    if (id == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _lineFocusNodes[id]?.requestFocus();
      _pendingFocusLineId = null;
    });
  }

  int? _lineIndexById(String? id) {
    if (id == null) {
      return null;
    }
    for (int index = 0; index < _lines.length; index++) {
      if (_lines[index].id == id) {
        return index;
      }
    }
    return null;
  }

  int _resolveInsertLineIndex() {
    for (int index = 0; index < _lines.length; index++) {
      final FocusNode? node = _lineFocusNodes[_lines[index].id];
      if (node != null && node.hasFocus) {
        return index;
      }
    }
    final int? focusedIndex = _lineIndexById(_focusedLineId);
    if (focusedIndex != null) {
      return focusedIndex;
    }
    return _lines.isEmpty ? 0 : _lines.length - 1;
  }

  int _resolveInsertTextOffset(int lineIndex) {
    final EditorBodyLine line = _lines[lineIndex];
    if (line is EditorTextLine) {
      final TextEditingController? controller = _lineControllers[line.id];
      final TextSelection selection =
          controller?.selection ?? const TextSelection.collapsed(offset: 0);
      if (selection.isValid) {
        return selection.baseOffset.clamp(0, line.text.length);
      }
      return line.text.length;
    }
    return 0;
  }

  void insertCheckboxAtCursor() {
    final ({List<EditorBodyLine> lines, int lineIndex, int textOffset})
    context = _resolveCheckboxInsertContext();
    if (context.lines.isEmpty) {
      return;
    }
    _insertCheckboxAt(
      lines: context.lines,
      lineIndex: context.lineIndex,
      textOffset: context.textOffset,
    );
  }

  ({List<EditorBodyLine> lines, int lineIndex, int textOffset})
  _resolveCheckboxInsertContext() {
    if (!editorLinesHaveCheckbox(_lines)) {
      final String text = widget.bodyController.text;
      final TextSelection selection = widget.bodyController.selection;
      final int offset = selection.isValid
          ? selection.baseOffset.clamp(0, text.length)
          : text.length;
      final List<EditorBodyLine> lines = reparseEditorBodyLinesPreservingIds(
        text,
        previousLines: _lines,
      );
      if (lines.isEmpty) {
        return (lines: <EditorBodyLine>[], lineIndex: 0, textOffset: 0);
      }
      final ({int lineIndex, int textOffset}) position = offsetToLinePosition(
        text,
        offset,
      );
      return (
        lines: lines,
        lineIndex: position.lineIndex.clamp(0, lines.length - 1),
        textOffset: position.textOffset,
      );
    }

    _refreshLinesFromControllers();
    final int lineIndex = _resolveInsertLineIndex();
    return (
      lines: _lines,
      lineIndex: lineIndex,
      textOffset: _resolveInsertTextOffset(lineIndex),
    );
  }

  void _insertCheckboxAt({
    required List<EditorBodyLine> lines,
    required int lineIndex,
    required int textOffset,
  }) {
    final ({List<EditorBodyLine> lines, String checkboxId}) result =
        insertCheckboxAtLineIndex(
          lines: lines,
          lineIndex: lineIndex,
          textOffset: textOffset,
        );
    if (result.checkboxId.isEmpty) {
      return;
    }
    _applyLines(result.lines, focusLineId: result.checkboxId);
  }

  void _applyLines(List<EditorBodyLine> lines, {String? focusLineId}) {
    _lines = ensureEditorBodyLinesForEditing(lines);
    _commitLines(ensureTrailing: false, refreshControllers: false);
    _syncEditingSurfaceMode(focusLineId: focusLineId);
  }

  void _insertCheckboxAfter(int lineIndex) {
    _refreshLinesFromControllers();
    _insertCheckboxAt(lines: _lines, lineIndex: lineIndex, textOffset: 0);
  }

  void _toggleCheckbox(String lineId, bool checked) {
    _refreshLinesFromControllers();
    _lines = _lines.map((EditorBodyLine line) {
      if (line is EditorCheckboxLine && line.id == lineId) {
        return line.copyWith(checked: checked);
      }
      return line;
    }).toList();
    _commitLines();
    if (mounted) {
      setState(() {});
    }
  }

  void _updateLineText(String lineId, String text) {
    if (text.contains('\n')) {
      _splitTextLineAtNewlines(lineId, text);
      return;
    }
    final int? lineIndex = _lineIndexById(lineId);
    if (lineIndex == null) {
      return;
    }
    final EditorBodyLine line = _lines[lineIndex];
    if (_lineText(line) == text) {
      return;
    }
    _lines = _lines.map((EditorBodyLine entry) {
      if (entry.id != lineId) {
        return entry;
      }
      return switch (entry) {
        EditorTextLine() => entry.copyWith(text: text),
        EditorCheckboxLine() => entry.copyWith(text: text),
      };
    }).toList();
    _commitLines(refreshControllers: false);
  }

  void _splitTextLineAtNewlines(String lineId, String text) {
    final int? lineIndex = _lineIndexById(lineId);
    if (lineIndex == null) {
      return;
    }
    _refreshLinesFromControllers();
    final List<String> parts = text.split('\n');
    if (parts.isEmpty) {
      return;
    }
    final List<EditorBodyLine> replacement = <EditorBodyLine>[
      for (int index = 0; index < parts.length; index++)
        if (index == 0)
          (_lines[lineIndex] as EditorTextLine).copyWith(text: parts[index])
        else
          EditorTextLine(id: generateEditorLineId(), text: parts[index]),
    ];
    _applyLines(<EditorBodyLine>[
      ..._lines.sublist(0, lineIndex),
      ...replacement,
      ..._lines.sublist(lineIndex + 1),
    ]);
  }

  KeyEventResult _handleTextLineKeyEvent({
    required String lineId,
    required int lineIndex,
    required KeyEvent event,
  }) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      final TextEditingController? controller = _lineControllers[lineId];
      if (controller == null) {
        return KeyEventResult.ignored;
      }
      final TextSelection selection = controller.selection;
      if (!selection.isValid || !selection.isCollapsed) {
        return KeyEventResult.ignored;
      }
      if (selection.baseOffset != 0) {
        return KeyEventResult.ignored;
      }

      final EditorBodyLine line = _lines[lineIndex];
      if (line is! EditorTextLine) {
        return KeyEventResult.ignored;
      }

      if (line.text.isEmpty) {
        if (_lines.length > 1) {
          _deleteLineAt(lineIndex);
        }
        return KeyEventResult.handled;
      }

      if (lineIndex > 0 && _lines[lineIndex - 1] is EditorTextLine) {
        _mergeTextLineWithPrevious(lineIndex);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _insertTextLineAfter(lineIndex);
    return KeyEventResult.handled;
  }

  void _mergeTextLineWithPrevious(int lineIndex) {
    _refreshLinesFromControllers();
    final EditorTextLine previous = _lines[lineIndex - 1] as EditorTextLine;
    final EditorTextLine current = _lines[lineIndex] as EditorTextLine;
    final int mergeOffset = previous.text.length;
    final String previousId = previous.id;
    _applyLines(<EditorBodyLine>[
      ..._lines.sublist(0, lineIndex - 1),
      previous.copyWith(text: '${previous.text}${current.text}'),
      ..._lines.sublist(lineIndex + 1),
    ], focusLineId: previousId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final TextEditingController? controller = _lineControllers[previousId];
      if (controller == null) {
        return;
      }
      controller.selection = TextSelection.collapsed(offset: mergeOffset);
    });
  }

  void _deleteLineAt(int lineIndex) {
    _refreshLinesFromControllers();
    if (lineIndex < 0 || lineIndex >= _lines.length) {
      return;
    }
    final bool wasHybrid = _hybridMode;
    _lines = <EditorBodyLine>[
      ..._lines.sublist(0, lineIndex),
      ..._lines.sublist(lineIndex + 1),
    ];
    if (_lines.isEmpty) {
      _lines = <EditorBodyLine>[
        EditorTextLine(id: generateEditorLineId(), text: ''),
      ];
    }
    _lines = ensureEditorBodyLinesForEditing(_lines);
    _commitLines(refreshControllers: false);
    if (editorLinesHaveCheckbox(_lines)) {
      final int focusIndex = (lineIndex - 1).clamp(0, _lines.length - 1);
      _syncEditingSurfaceMode(focusLineId: _lines[focusIndex].id);
      return;
    }
    _syncEditingSurfaceMode(plainTextOffset: wasHybrid ? 0 : null);
  }

  KeyEventResult _handleCheckboxKeyEvent({
    required String lineId,
    required KeyEvent event,
  }) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    final TextEditingController? controller = _lineControllers[lineId];
    if (controller == null ||
        controller.text.isNotEmpty ||
        controller.selection.baseOffset != 0) {
      return KeyEventResult.ignored;
    }
    final int? lineIndex = _lineIndexById(lineId);
    if (lineIndex == null) {
      return KeyEventResult.ignored;
    }
    _deleteLineAt(lineIndex);
    return KeyEventResult.handled;
  }

  void _onReorderLine(int oldIndex, int newIndex) {
    _refreshLinesFromControllers();
    _lines = reorderEditorBodyLines(
      lines: _lines,
      oldIndex: oldIndex,
      newIndex: newIndex,
      newIndexAlreadyAdjusted: true,
    );
    _pruneControllers();
    _syncControllersWithLines();
    _commitLines();
    if (mounted) {
      setState(() {});
    }
  }

  TextStyle _bodyStyle(BuildContext context) {
    return widget.typography.bodyTextStyle(Theme.of(context).textTheme);
  }

  InputDecoration _plainTextDecoration(BuildContext context, TextStyle style) {
    return InputDecoration(
      filled: false,
      fillColor: Colors.transparent,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      isDense: true,
      hintText: context.l10n.editorBodyHint,
      hintStyle: style.copyWith(
        color: context.appColors.mutedForeground,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  InputDecoration _lineDecoration({String? hintText, TextStyle? hintStyle}) {
    return InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      isDense: true,
      hintText: hintText,
      hintStyle: hintStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle bodyStyle = _bodyStyle(context);

    if (!_hybridMode) {
      return TextField(
        controller: widget.bodyController,
        focusNode: _plainTextFocusNode,
        expands: true,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: bodyStyle,
        onChanged: (_) => widget.onBodyChanged(),
        decoration: _plainTextDecoration(context, bodyStyle),
      );
    }

    return ReorderableListView.builder(
      padding: EdgeInsets.zero,
      buildDefaultDragHandles: false,
      itemCount: _lines.length,
      onReorderItem: _onReorderLine,
      itemBuilder: (BuildContext context, int lineIndex) {
        final EditorBodyLine line = _lines[lineIndex];
        return KeyedSubtree(
          key: ValueKey<String>(line.id),
          child: switch (line) {
            EditorTextLine() => _buildTextLine(context, lineIndex, bodyStyle),
            EditorCheckboxLine() => _buildCheckboxLine(
              context,
              lineIndex,
              bodyStyle,
              reorderIndex: lineIndex,
            ),
          },
        );
      },
    );
  }

  Widget _buildLineDragHandle(BuildContext context, int reorderIndex) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ReorderableDragStartListener(
      index: reorderIndex,
      child: Tooltip(
        message: context.l10n.editorCheckboxDragTooltip,
        child: Padding(
          padding: const EdgeInsets.only(right: 4, top: 2),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              Icons.drag_handle_rounded,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextLine(
    BuildContext context,
    int lineIndex,
    TextStyle bodyStyle,
  ) {
    final EditorBodyLine line = _lines[lineIndex];
    if (line is! EditorTextLine) {
      return const SizedBox.shrink();
    }
    final TextEditingController controller = _controllerForLine(line);
    return Padding(
      padding: EdgeInsets.only(bottom: widget.typography.bodyParagraphSpacing),
      child: TextField(
        controller: controller,
        focusNode: _lineFocusNodes[line.id],
        minLines: 1,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: bodyStyle,
        decoration: _lineDecoration(),
      ),
    );
  }

  void _insertTextLineAfter(int lineIndex) {
    _refreshLinesFromControllers();
    final List<EditorBodyLine> next = insertTextLineAfter(
      lines: _lines,
      lineIndex: lineIndex,
    );
    _applyLines(next, focusLineId: next[lineIndex + 1].id);
  }

  Widget _buildCheckboxLine(
    BuildContext context,
    int lineIndex,
    TextStyle bodyStyle, {
    required int reorderIndex,
  }) {
    final EditorBodyLine line = _lines[lineIndex];
    if (line is! EditorCheckboxLine) {
      return const SizedBox.shrink();
    }
    return EditorCheckboxBlockRow(
      block: line,
      typography: widget.typography,
      bodyStyle: bodyStyle,
      editable: true,
      textController: _controllerForLine(line),
      textFocusNode: _lineFocusNodes[line.id],
      onCheckedChanged: (bool checked) => _toggleCheckbox(line.id, checked),
      onTextChanged: (String text) => _updateLineText(line.id, text),
      onSubmitted: () => _insertCheckboxAfter(lineIndex),
      dragHandle: _buildLineDragHandle(context, reorderIndex),
    );
  }
}
