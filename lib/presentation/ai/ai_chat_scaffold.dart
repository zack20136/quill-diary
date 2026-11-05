import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';

class AiChatScaffold extends StatelessWidget {
  const AiChatScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.onPreview,
    required this.onDelete,
    required this.deleteTooltip,
    this.leading,
  });
  final String title;
  final Widget body;
  final VoidCallback? onPreview;
  final VoidCallback? onDelete;
  final String deleteTooltip;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      IconButton(
        tooltip: context.l10n.aiPreviewRequest,
        onPressed: onPreview,
        icon: const Icon(Icons.visibility_outlined),
      ),
      IconButton(
        tooltip: deleteTooltip,
        onPressed: onDelete,
        style: IconButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        icon: const Icon(Icons.delete_outline),
      ),
    ];
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final separate =
        MediaQuery.sizeOf(context).width <
        56 + 32 + painter.width + 2 * kMinInteractiveDimension;
    painter.dispose();
    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: separate ? null : actions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (separate)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(alignment: WrapAlignment.end, children: actions),
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
