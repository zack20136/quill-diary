import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_composer_actions.dart';
import 'package:quill_diary/shared/presentation/widgets/app_choice_card.dart';

class OrganizationQuickActions extends StatelessWidget {
  const OrganizationQuickActions({
    super.key,
    required this.enabled,
    required this.onSelected,
    this.compact = false,
  });
  final bool enabled;
  final ValueChanged<String> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final choices = [
      (
        l10n.organizationPolish,
        l10n.organizationPolishDescription,
        l10n.organizationPolishRequest,
        Icons.auto_fix_high_outlined,
      ),
      (
        l10n.organizationCondense,
        l10n.organizationCondenseDescription,
        l10n.organizationCondenseRequest,
        Icons.short_text,
      ),
      (
        l10n.organizationStructure,
        l10n.organizationStructureDescription,
        l10n.organizationStructureRequest,
        Icons.view_agenda_outlined,
      ),
      (
        l10n.organizationElaborate,
        l10n.organizationElaborateDescription,
        l10n.organizationElaborateRequest,
        Icons.question_answer_outlined,
      ),
    ];
    if (compact) {
      return SingleChildScrollView(
        key: const ValueKey('organization-quick-bar'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            for (var i = 0; i < choices.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              AiComposerActionButton(
                actionKey: ValueKey('organization-quick-$i'),
                label: choices[i].$1,
                tooltip: choices[i].$2,
                onPressed: enabled ? () => onSelected(choices[i].$3) : null,
              ),
            ],
          ],
        ),
      );
    }
    final cards = [
      for (var i = 0; i < choices.length; i++)
        AppChoiceCard(
          key: ValueKey('organization-quick-$i'),
          icon: choices[i].$4,
          title: choices[i].$1,
          description: choices[i].$2,
          onPressed: enabled ? () => onSelected(choices[i].$3) : null,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.organizationChooseDirection,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.organizationChooseDirectionHint,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns =
                  constraints.maxWidth >= 560 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 19.6;
              if (!twoColumns) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      cards[i],
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (var row = 0; row < 2; row++) ...[
                    if (row > 0) const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: cards[row * 2]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[row * 2 + 1]),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
