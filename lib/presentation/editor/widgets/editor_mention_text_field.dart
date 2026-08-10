import 'package:flutter/material.dart';

import 'package:quill_diary/application/editor/editor_person_mention_controller.dart';

class EditorMentionTextField extends StatefulWidget {
  const EditorMentionTextField({
    required this.controller,
    required this.style,
    required this.decoration,
    this.mentionController,
    this.onMentionKeyEvent,
    this.focusNode,
    this.textInputAction,
    this.expands = false,
    this.maxLines = 1,
    this.minLines,
    this.textAlignVertical,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final TextStyle style;
  final InputDecoration decoration;
  final EditorPersonMentionController? mentionController;
  final KeyEventResult Function(FocusNode node, KeyEvent event)?
  onMentionKeyEvent;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool expands;
  final int? maxLines;
  final int? minLines;
  final TextAlignVertical? textAlignVertical;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<EditorMentionTextField> createState() => _EditorMentionTextFieldState();
}

class _EditorMentionTextFieldState extends State<EditorMentionTextField> {
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _ownedFocusNode = FocusNode();
    }
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(EditorMentionTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocusNode)?.removeListener(_onFocusChanged);
      if (widget.focusNode == null && _ownedFocusNode == null) {
        _ownedFocusNode = FocusNode();
      }
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final EditorPersonMentionController? mention = widget.mentionController;
    if (_focusNode.hasFocus) {
      mention?.bind(widget.controller);
    } else if (mention != null && mention.isBoundTo(widget.controller)) {
      mention.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: widget.onMentionKeyEvent,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        textInputAction: widget.textInputAction,
        expands: widget.expands,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        textAlignVertical: widget.textAlignVertical,
        keyboardType: widget.keyboardType,
        style: widget.style,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted == null
            ? null
            : (_) => widget.onSubmitted!(),
        onTap: () => widget.mentionController?.syncFromActiveController(),
        decoration: widget.decoration,
      ),
    );
  }
}
