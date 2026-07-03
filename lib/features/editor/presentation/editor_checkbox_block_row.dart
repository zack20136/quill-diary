import 'package:flutter/material.dart';

import '../../../infrastructure/preferences/editor_typography_preferences.dart';
import '../application/editor_body_blocks.dart';

class EditorCheckboxBlockRow extends StatelessWidget {
  const EditorCheckboxBlockRow({
    super.key,
    required this.block,
    required this.typography,
    required this.bodyStyle,
    required this.editable,
    this.textController,
    required this.onCheckedChanged,
    required this.onTextChanged,
    this.textFocusNode,
    this.onSubmitted,
    this.dragHandle,
  });

  final EditorCheckboxLine block;
  final EditorTypographyPreferences typography;
  final TextStyle bodyStyle;
  final bool editable;
  final TextEditingController? textController;
  final ValueChanged<bool> onCheckedChanged;
  final ValueChanged<String> onTextChanged;
  final FocusNode? textFocusNode;
  final VoidCallback? onSubmitted;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextStyle labelStyle = bodyStyle.copyWith(
      color: block.checked ? cs.onSurfaceVariant.withValues(alpha: 0.72) : null,
      decoration: block.checked ? TextDecoration.lineThrough : null,
      decorationColor: cs.onSurfaceVariant.withValues(alpha: 0.55),
    );

    final Widget checkbox = SelectionContainer.disabled(
      child: SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: block.checked,
          onChanged: (bool? value) {
            if (value != null) {
              onCheckedChanged(value);
            }
          },
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );

    final Widget textField = editable
        ? TextField(
            focusNode: textFocusNode,
            controller: textController,
            onChanged: onTextChanged,
            onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
            textInputAction: TextInputAction.next,
            minLines: 1,
            maxLines: null,
            style: labelStyle,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          )
        : block.text.isEmpty
        ? const SizedBox.shrink()
        : Text(block.text, style: labelStyle);

    return Padding(
      padding: EdgeInsets.only(bottom: typography.bodyParagraphSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(padding: const EdgeInsets.only(top: 2), child: checkbox),
          const SizedBox(width: 4),
          Expanded(child: textField),
          if (editable && dragHandle != null) dragHandle!,
        ],
      ),
    );
  }
}
