import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/domain/chat_diary/chat_diary_generation.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_generation_label.dart';
import 'package:quill_diary/shared/presentation/widgets/app_progress.dart';

class ChatDiaryGenerationCard extends StatelessWidget {
  const ChatDiaryGenerationCard({
    super.key,
    required this.generation,
    required this.onStop,
  });

  final ChatDiaryGeneration generation;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Container(
        key: const ValueKey('chat-diary-generation-card'),
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
            Text(l10n.chatDiaryGenerating, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            AppLinearProgressIndicator(
              value: MediaQuery.disableAnimationsOf(context) ? 0.5 : null,
              minHeight: 6,
            ),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                chatDiaryGenerationPhaseLabel(l10n, generation.phase),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chatDiaryGenerationHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onStop,
                child: Text(l10n.chatDiaryStopGeneration),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
