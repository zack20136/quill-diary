import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/person_visual.dart';
import 'package:quill_diary/shared/presentation/tag_visual.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';

/// 建議列本體高度（不含外距）。
const double kEditorPersonSuggestionBarHeight = 48;

/// 正文需預留的底部空間（建議列 + 間距）。
const double kEditorPersonSuggestionBodyReserve =
    kEditorPersonSuggestionBarHeight + 8;

/// 編輯器 `@` 人物建議：貼齊鍵盤上方的單列橫向 chip 列。
class EditorPersonSuggestionPanel extends StatefulWidget {
  const EditorPersonSuggestionPanel({
    required this.suggestions,
    required this.highlightIndex,
    required this.catalogEmpty,
    required this.onSelected,
    required this.onCreatePerson,
    super.key,
  });

  final List<EditorPersonSuggestion> suggestions;
  final int highlightIndex;
  final bool catalogEmpty;
  final ValueChanged<EditorPersonSuggestion> onSelected;
  final VoidCallback onCreatePerson;

  @override
  State<EditorPersonSuggestionPanel> createState() =>
      _EditorPersonSuggestionPanelState();
}

class _EditorPersonSuggestionPanelState
    extends State<EditorPersonSuggestionPanel> {
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _chipKeys = const <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _syncChipKeys();
  }

  @override
  void didUpdateWidget(covariant EditorPersonSuggestionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestions.length != widget.suggestions.length) {
      _syncChipKeys();
    }
    if (oldWidget.highlightIndex != widget.highlightIndex ||
        oldWidget.suggestions.length != widget.suggestions.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureHighlightVisible();
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _syncChipKeys() {
    _chipKeys = List<GlobalKey>.generate(
      widget.suggestions.length,
      (_) => GlobalKey(),
    );
  }

  void _ensureHighlightVisible() {
    if (widget.highlightIndex < 0 ||
        widget.highlightIndex >= _chipKeys.length) {
      return;
    }
    final BuildContext? chipContext =
        _chipKeys[widget.highlightIndex].currentContext;
    if (chipContext == null) {
      return;
    }
    unawaited(
      Scrollable.ensureVisible(
        chipContext,
        alignment: 0.35,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors appColors = context.appColors;

    final Widget body;
    if (widget.catalogEmpty) {
      body = _CreatePersonHint(
        text: context.l10n.editorMentionEmptyCatalog,
        onPressed: widget.onCreatePerson,
      );
    } else if (widget.suggestions.isEmpty) {
      body = _CreatePersonHint(
        text: context.l10n.editorMentionNoMatches,
        onPressed: widget.onCreatePerson,
      );
    } else {
      body = ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: widget.suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int index) {
          return KeyedSubtree(
            key: _chipKeys[index],
            child: Center(
              child: _PersonSuggestionChip(
                suggestion: widget.suggestions[index],
                selected: index == widget.highlightIndex,
                onSelected: () => widget.onSelected(widget.suggestions[index]),
                colorScheme: cs,
                appColors: appColors,
                labelStyle: theme.textTheme.labelMedium,
              ),
            ),
          );
        },
      );
    }

    // 固定單列高度，鍵盤開著時也只佔鍵盤上方一小條，避免蓋住輸入區。
    return Material(
      key: const ValueKey<String>('editor-person-suggestion-background'),
      color: cs.surfaceContainerHigh,
      elevation: 4,
      shadowColor: cs.shadow.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(height: kEditorPersonSuggestionBarHeight, child: body),
    );
  }
}

class _CreatePersonHint extends StatelessWidget {
  const _CreatePersonHint({required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _HintText(
            text: text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(context.l10n.editorMentionCreatePerson),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}

class _PersonSuggestionChip extends StatelessWidget {
  const _PersonSuggestionChip({
    required this.suggestion,
    required this.selected,
    required this.onSelected,
    required this.colorScheme,
    required this.appColors,
    required this.labelStyle,
  });

  final EditorPersonSuggestion suggestion;
  final bool selected;
  final VoidCallback onSelected;
  final ColorScheme colorScheme;
  final AppColors appColors;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final (Color chipBg, Color chipFg) = personLabelColorPair(
      suggestion.person,
      appColors.sectionInset,
    );

    return FilterChip(
      label: Text(
        suggestion.person.diaryMentionLabel,
        style: labelStyle?.copyWith(color: chipFg, fontWeight: FontWeight.w700),
      ),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: chipBg,
      selectedColor: chipBg,
      side: tagBorderSide(
        appColors,
        colorScheme,
        chipBg,
        chipFg,
        width: selected ? 1.2 : 0.92,
        accentBorderAlpha: selected ? 0.55 : kAccentBorderAlpha,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
