import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/persona/persona_controller.dart';
import 'package:quill_diary/application/persona/persona_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/persona/persona_labels.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';

class PersonaSummarySection extends ConsumerWidget {
  const PersonaSummarySection({super.key, required this.personId});
  final String personId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(personaRecordProvider(personId));
    final controller = ref.watch(personaControllerProvider(personId));
    final l = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (_, _) {
        final record = controller.record ?? saved.value;
        final detailStyle = Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
        final updatedAt = record?.available == true
            ? record!.cards!.values
                  .map((card) => card.updatedAt)
                  .reduce((a, b) => a.isAfter(b) ? a : b)
            : null;
        return AppSectionCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          headerGap: 12,
          title: l.personaTitle,
          trailing: TextButton.icon(
            onPressed: !ref.watch(aiEnabledProvider)
                ? null
                : () => context.push(AppRoutes.personaLocation(personId)),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(l.personaManage),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller.generating) ...[
                const LinearProgressIndicator(),
                Text(
                  personaGenerationPhaseLabel(l, controller.generationPhase),
                ),
                if (controller.batchProgress case final batch?)
                  Text(
                    l.personaBatchProgress(
                      batch.round,
                      batch.completed,
                      batch.total,
                    ),
                  ),
              ],
              if (saved.hasError) Text(l.personaNeedsRecovery),
              if (record?.available == true) ...[
                Text(l.personaSummaryReady),
                if (record?.draft == null) ...[
                  const SizedBox(height: 6),
                  Text(
                    l.personaUpdatedAt(
                      DisplayFormat.formatDateTimeWithoutWeekday(l, updatedAt!),
                    ),
                    style: detailStyle,
                  ),
                ],
              ] else if (record?.draft == null && !saved.hasError) ...[
                Text(l.personaSummaryCreate),
              ],
              if (record?.draft != null) ...[
                if (record?.available == true) const SizedBox(height: 6),
                Text(
                  l.personaDraftProgress(
                    record?.available == true
                        ? l.personaUpdatingHint
                        : l.personaCreatingHint,
                    personaStepLabel(l, record!.draft!.step),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
