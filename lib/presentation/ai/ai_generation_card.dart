import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/widgets/app_progress.dart';

class AiGenerationCard extends StatelessWidget {
  const AiGenerationCard({
    super.key,
    required this.title,
    required this.status,
    required this.hint,
    required this.onStop,
    this.cardKey,
  });
  final String title;
  final String status;
  final String hint;
  final VoidCallback onStop;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Container(
        key: cardKey,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            AppLinearProgressIndicator(
              value: MediaQuery.disableAnimationsOf(context) ? 0.5 : null,
              minHeight: 6,
            ),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(status, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: 8),
            Text(hint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onStop,
                child: Text(context.l10n.aiStopGeneration),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
