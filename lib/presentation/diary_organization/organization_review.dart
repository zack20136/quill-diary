import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/diary_organization/diary_organization_controller.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/diary_organization/organization_diff.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_markdown_preview.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_segmented_choice_bar.dart';

class OrganizationReview extends ConsumerStatefulWidget {
  const OrganizationReview({
    super.key,
    required this.controller,
    required this.notices,
    required this.onBack,
    required this.onEdit,
    required this.onApply,
  });
  final DiaryOrganizationController controller;
  final Widget notices;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onApply;

  @override
  ConsumerState<OrganizationReview> createState() => _OrganizationReviewState();
}

class _OrganizationReviewState extends ConsumerState<OrganizationReview> {
  bool _fullText = false;
  String? _original;
  String? _revised;
  List<OrganizationDiffLine> _lines = [];

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final draft = controller.draft!;
    final original = draft.source.markdownBody;
    final revised = draft.restoredBody;
    if (original != _original || revised != _revised) {
      _original = original;
      _revised = revised;
      _lines = organizationDiffLines(original, revised);
    }
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final typography = watchPersonalizationPreferences(ref).typography;
    final canModify =
        !controller.busy &&
        !controller.conflict &&
        !controller.editorDraftExists;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PageStyle.pageHorizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.notices,
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
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                    child: _fullText
                        ? SelectionArea(
                            child: SingleChildScrollView(
                              key: const ValueKey('organization-full-text'),
                              padding: const EdgeInsets.all(16),
                              child: EditorMarkdownPreview(
                                markdown: revised,
                                typography: typography,
                              ),
                            ),
                          )
                        : OrganizationDiffView(
                            lines: _lines,
                            textStyle: typography
                                .bodyTextStyle(Theme.of(context).textTheme)
                                .copyWith(
                                  fontSize: math.min(
                                    typography.bodyFontSize,
                                    16,
                                  ),
                                  height: 1.4,
                                ),
                          ),
                  ),
                ),
              ),
              SafeArea(
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
            ],
          ),
        ),
      ),
    );
  }
}

class OrganizationDiffView extends StatelessWidget {
  const OrganizationDiffView({
    super.key,
    required this.lines,
    required this.textStyle,
  });
  final List<OrganizationDiffLine> lines;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final added = dark ? const Color(0xff7ee2a8) : const Color(0xff196c3b);
    final removed = dark ? const Color(0xffffa7a7) : const Color(0xffa83038);
    final gutterWidth =
        MediaQuery.textScalerOf(context).scale(textStyle.fontSize ?? 16) + 16;
    return SelectionArea(
      child: ListView.builder(
        key: const ValueKey('organization-diff-view'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          if (line.kind == OrganizationDiffKind.same &&
              line.text.trim().isEmpty) {
            return const SizedBox(height: 8);
          }
          final color = switch (line.kind) {
            OrganizationDiffKind.same => colors.onSurface,
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
                      child: Text.rich(
                        TextSpan(
                          children: [
                            for (final span in line.spans)
                              TextSpan(
                                text: span.text.replaceAll(
                                  RegExp(r'[\r\n]'),
                                  '',
                                ),
                                style: TextStyle(
                                  backgroundColor:
                                      span.kind == OrganizationDiffKind.same
                                      ? null
                                      : color.withValues(
                                          alpha: dark ? 0.22 : 0.16,
                                        ),
                                ),
                              ),
                          ],
                        ),
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
      ),
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
    final colors = theme.colorScheme;
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
            foregroundColor: i == 2 ? colors.primary : colors.onSurface,
            side: BorderSide(
              color: i == 2 && onApply != null
                  ? colors.primary
                  : colors.outlineVariant,
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
