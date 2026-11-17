import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_layout.dart';

/// 寬螢幕用置中對話框，窄螢幕用 bottom sheet。內容由 [builder] 提供。
Future<T?> showAdaptivePanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final colors = Theme.of(context).colorScheme;
  final wide = MediaQuery.sizeOf(context).width >= PageStyle.wideBreakpoint;
  if (wide) {
    return showAppDialog<T>(
      context: context,
      builder: (dialogContext) => Center(
        child: AppResponsiveWidth(
          widthFactor: 1,
          maxWidth: 480,
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            backgroundColor: colors.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PageStyle.radiusCard),
            ),
            clipBehavior: Clip.antiAlias,
            child: builder(dialogContext),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: colors.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(PageStyle.radiusCard),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    builder: builder,
  );
}

/// 選擇面板的把手、標題列與可捲動內容。選項由 [child] 提供。
class AdaptiveChoicePanel extends StatelessWidget {
  const AdaptiveChoicePanel({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.panelKey,
    this.handleKey,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final Key? panelKey;
  final Key? handleKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= PageStyle.wideBreakpoint;
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.6),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppDialogInsets.horizontal,
              wide ? 16 : 12,
              AppDialogInsets.horizontal,
              20,
            ),
            child: Column(
              key: panelKey,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!wide) ...[
                  Center(
                    child: Container(
                      key: handleKey,
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant,
                        borderRadius: BorderRadius.circular(
                          PageStyle.radiusPanel,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title, style: theme.textTheme.titleLarge),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.commonCloseTooltip,
                      onPressed: onClose,
                      style: IconButton.styleFrom(
                        foregroundColor: colors.onSurface,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: AppDialogScope(child: AppScrollView(child: child)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
