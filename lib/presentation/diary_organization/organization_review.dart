import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/diary_organization/diary_organization_controller.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/diary_organization/organization_diff.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_markdown_preview.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/private_text_spans.dart';
import 'package:quill_diary/shared/presentation/widgets/app_segmented_choice_bar.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

class OrganizationReview extends ConsumerStatefulWidget {
  const OrganizationReview({
    super.key,
    required this.controller,
    required this.notices,
    required this.onBack,
    required this.onEdit,
    required this.onApply,
    this.onShowReply,
  });
  final DiaryOrganizationController controller;
  final Widget notices;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onApply;
  final VoidCallback? onShowReply;

  @override
  ConsumerState<OrganizationReview> createState() => _OrganizationReviewState();
}

class _OrganizationReviewState extends ConsumerState<OrganizationReview> {
  bool _fullText = false;
  String? _original;
  String? _revised;
  List<OrganizationDiffLine> _lines = [];
  final ScrollController _diffScroll = ScrollController();
  final ScrollController _textScroll = ScrollController();

  ScrollController get _panelScroll => _fullText ? _textScroll : _diffScroll;

  @override
  void dispose() {
    _diffScroll.dispose();
    _textScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final draft = controller.draft!;
    final l10n = context.l10n;
    if (draft.hasUnsafeCandidate) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.organizationUnsafeCandidate),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: controller.busy ? null : widget.onBack,
                child: Text(l10n.organizationBack),
              ),
            ],
          ),
        ),
      );
    }
    final original = draft.source.markdownBody;
    final revised = draft.restoredBody;
    if (original != _original || revised != _revised) {
      _original = original;
      _revised = revised;
      _lines = organizationDiffLines(original, revised);
    }
    final cs = Theme.of(context).colorScheme;
    final typography = watchPersonalizationPreferences(ref).typography;
    final canModify =
        !controller.busy &&
        !controller.conflict &&
        !controller.editorDraftExists;
    const EdgeInsets side = EdgeInsets.only(
      right: PageStyle.pageHorizontalPadding,
    );
    return Padding(
      padding: const EdgeInsets.only(left: PageStyle.pageHorizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: side,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.notices,
                if (draft.visibleGenerationReply case final reply?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.organizationReplyTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final style = Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                );
                            final painter = TextPainter(
                              text: TextSpan(text: reply, style: style),
                              maxLines: 1,
                              textDirection: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                            )..layout(maxWidth: constraints.maxWidth);
                            final overflow = painter.didExceedMaxLines;
                            painter.dispose();
                            final preview = Text(
                              reply,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: style,
                            );
                            if (!overflow || widget.onShowReply == null) {
                              return preview;
                            }
                            return Row(
                              children: [
                                Expanded(child: preview),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                  onPressed: widget.onShowReply,
                                  child: Text(l10n.organizationShowReply),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AppSegmentedChoiceBar<bool>(
                    choices: [
                      AppSegmentChoice(
                        value: false,
                        label: l10n.organizationDiff,
                        icon: Icons.difference_outlined,
                      ),
                      AppSegmentChoice(
                        value: true,
                        label: l10n.organizationFullText,
                        icon: Icons.article_outlined,
                      ),
                    ],
                    selected: _fullText,
                    onSelected: (value) async =>
                        setState(() => _fullText = value),
                  ),
                ),
                if (original == revised)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(l10n.organizationNoChanges),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AppScrollbar(
              controller: _panelScroll,
              reserveGutter: true,
              track: AppScrollbarTrack.frame,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                  child: _fullText
                      ? SelectionArea(
                          child: SingleChildScrollView(
                            key: const ValueKey('organization-full-text'),
                            controller: _textScroll,
                            padding: const EdgeInsets.all(16),
                            child: EditorMarkdownPreview(
                              markdown: revised,
                              typography: typography,
                            ),
                          ),
                        )
                      : OrganizationDiffView(
                          lines: _lines,
                          scrollController: _diffScroll,
                          textStyle: typography
                              .bodyTextStyle(Theme.of(context).textTheme)
                              .copyWith(
                                fontSize: math.min(typography.bodyFontSize, 16),
                                height: 1.4,
                              ),
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: side,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _ReviewActions(
                  onBack: controller.busy ? null : widget.onBack,
                  onEdit: canModify ? widget.onEdit : null,
                  onApply: canModify && original != revised
                      ? widget.onApply
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrganizationDiffView extends StatelessWidget {
  const OrganizationDiffView({
    super.key,
    required this.lines,
    required this.textStyle,
    this.scrollController,
    this.panel = false,
    this.shrinkWrap = false,
  });
  final List<OrganizationDiffLine> lines;
  final TextStyle textStyle;

  /// 外層已有捲軸時傳入，清單不再自帶捲軸。
  final ScrollController? scrollController;

  /// 嵌在有圓角的區塊裡時，捲軸畫在區塊內，並留出左右間距。
  final bool panel;

  /// 包在外層捲動區時，清單跟著內容增高。
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final list = _DiffLineList(lines: lines, textStyle: textStyle);
    if (panel) return _DiffPanel(child: list, shrinkWrap: shrinkWrap);
    return SelectionArea(
      child: list.build(
        context,
        controller: scrollController!,
        padding: const EdgeInsets.symmetric(vertical: 4),
      ),
    );
  }
}

class _DiffPanel extends StatefulWidget {
  const _DiffPanel({required this.child, required this.shrinkWrap});
  final _DiffLineList child;
  final bool shrinkWrap;

  @override
  State<_DiffPanel> createState() => _DiffPanelState();
}

class _DiffPanelState extends State<_DiffPanel> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: AppScrollbar(
        controller: _scroll,
        reserveGutter: true,
        child: widget.child.build(
          context,
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          primary: false,
          shrinkWrap: widget.shrinkWrap,
          physics: widget.shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
        ),
      ),
    );
  }
}

class _DiffLineList {
  const _DiffLineList({required this.lines, required this.textStyle});
  final List<OrganizationDiffLine> lines;
  final TextStyle textStyle;

  Widget build(
    BuildContext context, {
    required ScrollController controller,
    required EdgeInsets padding,
    bool? primary,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
  }) {
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final added = dark ? const Color(0xff7ee2a8) : const Color(0xff196c3b);
    final removed = dark ? const Color(0xffffa7a7) : const Color(0xffa83038);
    final gutterWidth =
        MediaQuery.textScalerOf(context).scale(textStyle.fontSize ?? 16) + 16;
    return ListView.builder(
      controller: controller,
      primary: primary,
      shrinkWrap: shrinkWrap,
      physics: physics,
      key: const ValueKey('organization-diff-view'),
      padding: padding,
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        if (line.kind == OrganizationDiffKind.same &&
            line.text.trim().isEmpty) {
          return const SizedBox(height: 8);
        }
        final color = switch (line.kind) {
          OrganizationDiffKind.same => cs.onSurface,
          OrganizationDiffKind.removed => removed,
          OrganizationDiffKind.added => added,
        };
        final changed = line.kind != OrganizationDiffKind.same;
        return Semantics(
          label: switch (line.kind) {
            OrganizationDiffKind.same => null,
            OrganizationDiffKind.removed => context.l10n.organizationRemoved,
            OrganizationDiffKind.added => context.l10n.organizationAdded,
          },
          child: ColoredBox(
            key: ValueKey('organization-diff-line-$index'),
            color: changed
                ? color.withValues(alpha: dark ? 0.09 : 0.07)
                : Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectionContainer.disabled(
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: gutterWidth,
                        child: Text(
                          switch (line.kind) {
                            OrganizationDiffKind.same => '',
                            OrganizationDiffKind.removed => '−',
                            OrganizationDiffKind.added => '+',
                          },
                          textAlign: TextAlign.center,
                          style: textStyle.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _DiffLineText(
                      line: line,
                      color: color,
                      emphasize: dark ? 0.22 : 0.16,
                      style: textStyle.copyWith(
                        color: color,
                        decoration: line.kind == OrganizationDiffKind.removed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiffLineText extends StatelessWidget {
  const _DiffLineText({
    required this.line,
    required this.color,
    required this.emphasize,
    required this.style,
  });

  static final RegExp _lineBreak = RegExp(r'[\r\n]');

  final OrganizationDiffLine line;
  final Color color;
  final double emphasize;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final parts = <TextSpan>[];
    final displayed = StringBuffer();
    for (final span in line.spans) {
      final text = span.text.replaceAll(_lineBreak, '');
      displayed.write(text);
      parts.add(
        TextSpan(
          text: text,
          style: TextStyle(
            backgroundColor: span.kind == OrganizationDiffKind.same
                ? null
                : color.withValues(alpha: emphasize),
          ),
        ),
      );
    }
    final text = displayed.toString();
    return PrivateText.rich(
      TextSpan(children: parts),
      ranges: privacyTokenRanges(text),
      style: style,
    );
  }
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({
    required this.onBack,
    required this.onEdit,
    required this.onApply,
  });
  final VoidCallback? onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final labels = [
      context.l10n.organizationBack,
      context.l10n.organizationEditDraft,
      context.l10n.organizationApply,
    ];
    final callbacks = [onBack, onEdit, onApply];
    final buttons = <Widget>[
      for (var i = 0; i < labels.length; i++)
        OutlinedButton(
          key: i == 2 ? const ValueKey('organization-apply') : null,
          onPressed: callbacks[i],
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            foregroundColor: i == 2 ? cs.primary : cs.onSurface,
            side: BorderSide(
              color: i == 2 && onApply != null ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Text(labels[i]),
        ),
    ];
    buttons[0] = Tooltip(
      message: context.l10n.organizationBackHint,
      child: buttons[0],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        var requiredWidth = 0.0;
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: theme.textTheme.labelLarge),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          if (painter.width + 24 > requiredWidth) {
            requiredWidth = painter.width + 24;
          }
          painter.dispose();
        }
        if (requiredWidth * 3 + 24 > constraints.maxWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                buttons[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: buttons[i]),
            ],
          ],
        );
      },
    );
  }
}
