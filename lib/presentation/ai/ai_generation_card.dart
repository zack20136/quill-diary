import 'dart:async';

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
    this.progress,
    this.elapsed,
  });
  final String title;
  final String status;
  final String hint;
  final VoidCallback onStop;
  final Key? cardKey;
  final double? progress;
  final Duration Function()? elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = Semantics(
      liveRegion: true,
      child: Text(status, style: theme.textTheme.bodyMedium),
    );
    final readElapsed = elapsed;
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
              value:
                  progress ??
                  (MediaQuery.disableAnimationsOf(context) ? 0.5 : null),
              minHeight: 6,
            ),
            const SizedBox(height: 10),
            if (readElapsed == null)
              statusText
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(flex: 2, child: statusText),
                  const SizedBox(width: 8),
                  Expanded(child: _GenerationElapsed(readElapsed: readElapsed)),
                ],
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

class _GenerationElapsed extends StatefulWidget {
  const _GenerationElapsed({required this.readElapsed});

  final Duration Function() readElapsed;

  @override
  State<_GenerationElapsed> createState() => _GenerationElapsedState();
}

class _GenerationElapsedState extends State<_GenerationElapsed> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.readElapsed();
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Text(
      context.l10n.aiGenerationElapsed('${elapsed.inMinutes}:$seconds'),
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
