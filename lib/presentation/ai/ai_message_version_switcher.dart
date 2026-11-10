import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';

class AiMessageVersionSwitcher extends StatelessWidget {
  const AiMessageVersionSwitcher({
    super.key,
    required this.index,
    required this.count,
    required this.enabled,
    required this.onPrevious,
    required this.onNext,
  });

  final int index;
  final int count;
  final bool enabled;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: l10n.chatDiaryPreviousVersion,
          icon: const Icon(Icons.chevron_left, size: 18),
          onPressed: enabled && index > 0 ? onPrevious : null,
        ),
        Text(
          '${index + 1} / $count',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: l10n.chatDiaryNextVersion,
          icon: const Icon(Icons.chevron_right, size: 18),
          onPressed: enabled && index < count - 1 ? onNext : null,
        ),
      ],
    );
  }
}
