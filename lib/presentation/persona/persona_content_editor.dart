import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_content.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';

const _editorHeight = 260.0;

class PersonaContentEditor extends StatefulWidget {
  const PersonaContentEditor({
    super.key,
    required this.card,
    required this.kind,
    required this.names,
    required this.style,
    required this.valid,
    required this.onChanged,
  });
  final PersonaCandidate card;
  final PersonaCardKind kind;
  final Map<String, String> names;
  final TextStyle style;
  final bool valid;
  final ValueChanged<String> onChanged;

  @override
  State<PersonaContentEditor> createState() => _PersonaContentEditorState();
}

class _PersonaContentEditorState extends State<PersonaContentEditor> {
  final _controller = PersonaContentController();
  final _scroll = ScrollController();
  String? _locale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_locale != context.l10n.localeName) {
      _locale = context.l10n.localeName;
      _sync();
    }
  }

  @override
  void didUpdateWidget(PersonaContentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.protectedText != widget.card.text ||
        !mapEquals(oldWidget.names, widget.names) ||
        !mapEquals(oldWidget.card.tokens, widget.card.tokens)) {
      _sync();
    }
  }

  void _sync() => _controller.setContent(
    PersonaContent(
      widget.card,
      widget.names,
      unknownPerson: context.l10n.personaUnknownPerson,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final invalidBorder = OutlineInputBorder(
      borderSide: BorderSide(color: colors.error),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _editorHeight,
          child: AppScrollbar(
            controller: _scroll,
            track: AppScrollbarTrack.frame,
            child: TextFormField(
              controller: _controller,
              scrollController: _scroll,
              style: widget.style,
              textAlignVertical: TextAlignVertical.top,
              expands: true,
              minLines: null,
              maxLines: null,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                enabledBorder: widget.valid ? null : invalidBorder,
                focusedBorder: widget.valid
                    ? null
                    : OutlineInputBorder(
                        borderSide: BorderSide(color: colors.error, width: 2),
                      ),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: (_) => widget.onChanged(_controller.protectedText),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.valid ? '' : l10n.personaInvalidCard,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ),
            Text(
              '${widget.card.text.length} / ${PersonaLimits.card(widget.kind)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 編輯未碰到的姓名仍保留人物識別；改動該姓名時，僅該處改為一般文字。
class PersonaContentController extends TextEditingController {
  final _references = <({PrivateTextRange range, String token})>[];
  void setContent(PersonaContent content) {
    _references
      ..clear()
      ..addAll(
        content.references.map((r) => (range: r.visible, token: r.token)),
      );
    super.value = TextEditingValue(
      text: content.text,
      selection: TextSelection.collapsed(offset: content.text.length),
    );
  }

  String get protectedText {
    var result = text;
    for (final reference in _references.reversed) {
      result = result.replaceRange(
        reference.range.start,
        reference.range.end,
        reference.token,
      );
    }
    return result;
  }

  @override
  set value(TextEditingValue next) {
    if (text != next.text) {
      var start = 0;
      while (start < text.length &&
          start < next.text.length &&
          text[start] == next.text[start]) {
        start++;
      }
      var end = text.length;
      var nextEnd = next.text.length;
      while (end > start &&
          nextEnd > start &&
          text[end - 1] == next.text[nextEnd - 1]) {
        end--;
        nextEnd--;
      }
      final delta = next.text.length - text.length;
      final remaining = <({PrivateTextRange range, String token})>[];
      for (final reference in _references) {
        final range = reference.range;
        if (end <= range.start) {
          remaining.add((
            range: PrivateTextRange(range.start + delta, range.end + delta),
            token: reference.token,
          ));
        } else if (start >= range.end) {
          remaining.add(reference);
        }
      }
      _references
        ..clear()
        ..addAll(remaining);
    }
    super.value = next;
  }
}
