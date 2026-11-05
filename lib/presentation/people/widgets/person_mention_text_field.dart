import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/application/people/person_mention_controller.dart';

class PersonMentionTextField extends StatefulWidget {
  const PersonMentionTextField({
    required this.controller,
    required this.style,
    required this.decoration,
    this.mentionController,
    this.fieldKey,
    this.enabled = true,
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
  final PersonMentionController? mentionController;
  final Key? fieldKey;
  final bool enabled;
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
  State<PersonMentionTextField> createState() => _PersonMentionTextFieldState();
}

class _PersonMentionTextFieldState extends State<PersonMentionTextField> {
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
  void didUpdateWidget(PersonMentionTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocusNode)?.removeListener(_onFocusChanged);
      if (widget.focusNode == null && _ownedFocusNode == null) {
        _ownedFocusNode = FocusNode();
      }
      _focusNode.addListener(_onFocusChanged);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.mentionController != widget.mentionController ||
        oldWidget.enabled != widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onFocusChanged();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final PersonMentionController? mention = widget.mentionController;
    if (_focusNode.hasFocus && widget.enabled) {
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
        key: widget.fieldKey,
        enabled: widget.enabled,
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
        onTap: () => widget.mentionController?.bind(widget.controller),
        decoration: widget.decoration,
      ),
    );
  }
}
