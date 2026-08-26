import 'package:flutter/material.dart';

import 'package:quill_diary/application/editor/editor_body_blocks.dart';
import 'package:quill_diary/application/editor/editor_person_mention_controller.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'editor_mention_text_field.dart';

class EditorCheckboxBlockRow extends StatefulWidget {
  const EditorCheckboxBlockRow({
    super.key,
    required this.block,
    required this.typography,
    required this.bodyStyle,
    required this.editable,
    this.textController,
    this.onCheckedChanged,
    required this.onTextChanged,
    this.textFocusNode,
    this.mentionController,
    this.onMentionKeyEvent,
    this.onSubmitted,
    this.dragHandle,
  });

  final EditorCheckboxLine block;
  final EditorTypographyPreferences typography;
  final TextStyle bodyStyle;
  final bool editable;
  final TextEditingController? textController;
  final ValueChanged<bool>? onCheckedChanged;
  final ValueChanged<String> onTextChanged;
  final FocusNode? textFocusNode;
  final EditorPersonMentionController? mentionController;
  final KeyEventResult Function(FocusNode node, KeyEvent event)?
  onMentionKeyEvent;
  final VoidCallback? onSubmitted;
  final Widget? dragHandle;

  @override
  State<EditorCheckboxBlockRow> createState() => _EditorCheckboxBlockRowState();
}

class _EditorCheckboxBlockRowState extends State<EditorCheckboxBlockRow> {
  late bool _checked = widget.block.checked;

  @override
  void didUpdateWidget(covariant EditorCheckboxBlockRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.checked != _checked) {
      _checked = widget.block.checked;
    }
  }

  void _handleCheckedChanged(bool? value) {
    final ValueChanged<bool>? onCheckedChanged = widget.onCheckedChanged;
    if (onCheckedChanged == null || value == null || value == _checked) {
      return;
    }
    // 先更新本地狀態，讓 Material Checkbox 動畫不被父層重建打斷。
    setState(() => _checked = value);
    onCheckedChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextStyle labelStyle = widget.bodyStyle.copyWith(
      color: _checked ? cs.onSurfaceVariant.withValues(alpha: 0.72) : null,
      decoration: _checked ? TextDecoration.lineThrough : null,
      decorationColor: cs.onSurfaceVariant.withValues(alpha: 0.55),
    );

    // 視覺與第一行文字對齊；觸控仍靠 Checkbox 本身，不外擴成會把勾選框往下推的 44 盒。
    final Widget checkbox = SelectionContainer.disabled(
      child: SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: _checked,
          onChanged: widget.onCheckedChanged == null
              ? null
              : _handleCheckedChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );

    const InputDecoration fieldDecoration = InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      isDense: true,
    );
    final TextEditingController? controller = widget.textController;
    final EditorPersonMentionController? mention = widget.mentionController;
    final Widget textField = !widget.editable
        ? (widget.block.text.isEmpty
              ? const SizedBox.shrink()
              : Text(widget.block.text, style: labelStyle))
        : (mention == null || controller == null)
        ? TextField(
            focusNode: widget.textFocusNode,
            controller: controller,
            onChanged: widget.onTextChanged,
            onSubmitted: widget.onSubmitted == null
                ? null
                : (_) => widget.onSubmitted!(),
            textInputAction: TextInputAction.next,
            minLines: 1,
            maxLines: null,
            style: labelStyle,
            decoration: fieldDecoration,
          )
        : EditorMentionTextField(
            focusNode: widget.textFocusNode,
            controller: controller,
            mentionController: mention,
            onMentionKeyEvent: widget.onMentionKeyEvent,
            onChanged: widget.onTextChanged,
            onSubmitted: widget.onSubmitted,
            textInputAction: TextInputAction.next,
            minLines: 1,
            maxLines: null,
            style: labelStyle,
            decoration: fieldDecoration,
          );

    return Padding(
      padding: EdgeInsets.only(bottom: widget.typography.bodyParagraphSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(padding: const EdgeInsets.only(top: 2), child: checkbox),
          const SizedBox(width: 4),
          Expanded(child: textField),
          if (widget.editable && widget.dragHandle != null) widget.dragHandle!,
        ],
      ),
    );
  }
}
