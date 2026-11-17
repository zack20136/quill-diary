import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';

/// Dialog 的可見寬度尺寸。
enum AppDialogSize { standard, compact }

/// 置中 dialog 卡片相對可用高度的上限。
const double appDialogMaxHeightFactor = 0.9;

/// 標準 dialog 卡片相對可用寬度的比例。
const double appDialogStandardWidthFactor = 0.9;

/// 卡片本身的約束。寬度由 [AppDialogWidth] 決定，這裡只管高度。
///
/// [fillHeight] 為 true 時，卡片直接用到這個上限，而不是跟著內容縮短。
BoxConstraints appDialogConstraints(
  BuildContext context, {
  bool fillHeight = false,
}) {
  final double maxHeight =
      MediaQuery.sizeOf(context).height * appDialogMaxHeightFactor;
  return BoxConstraints(
    minWidth: double.infinity,
    minHeight: fillHeight ? maxHeight : 0,
    maxHeight: maxHeight,
  );
}

/// 將各種 dialog 的實際寬度統一為對應層級比例，高度最高為可用高度的 90%。
class AppDialogWidth extends StatelessWidget {
  const AppDialogWidth({
    super.key,
    required this.child,
    this.size = AppDialogSize.standard,
  });

  final Widget child;
  final AppDialogSize size;

  double get _widthFactor => switch (size) {
    AppDialogSize.standard => appDialogStandardWidthFactor,
    AppDialogSize.compact => 0.8,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth * _widthFactor
            : constraints.maxWidth;
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight * appDialogMaxHeightFactor
            : constraints.maxHeight;
        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: width,
              maxWidth: width,
              maxHeight: height,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// 以一致的寬度規則建立 dialog route；需要持有 route 的呼叫端使用此函式。
DialogRoute<T> appDialogRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  AppDialogSize size = AppDialogSize.standard,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useSafeArea = true,
}) {
  final Color resolvedBarrier =
      barrierColor ??
      DialogTheme.of(context).barrierColor ??
      Theme.of(context).dialogTheme.barrierColor ??
      Colors.black54;
  return DialogRoute<T>(
    context: context,
    builder: (BuildContext dialogContext) =>
        AppDialogWidth(size: size, child: builder(dialogContext)),
    barrierDismissible: barrierDismissible,
    barrierColor: resolvedBarrier,
    useSafeArea: useSafeArea,
  );
}

/// 顯示統一寬度規則的 dialog，行為與 [showDialog] 相同。
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  AppDialogSize size = AppDialogSize.standard,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useSafeArea = true,
}) => Navigator.of(context, rootNavigator: true).push(
  appDialogRoute<T>(
    context: context,
    builder: builder,
    size: size,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useSafeArea: useSafeArea,
  ),
);

/// 所有 dialog 共用的留白：左右 [horizontal]，上下依區塊分別設定。
abstract final class AppDialogInsets {
  static const double horizontal = 20;

  static const EdgeInsets title = EdgeInsets.fromLTRB(
    horizontal,
    20,
    horizontal,
    0,
  );
  static const EdgeInsets content = EdgeInsets.fromLTRB(
    horizontal,
    12,
    horizontal,
    12,
  );
  static const EdgeInsets actions = EdgeInsets.fromLTRB(
    horizontal,
    0,
    horizontal,
    12,
  );
}

/// 標記 dialog 內容範圍，供捲軸把右側留白當作自己的欄位使用。
class AppDialogScope extends InheritedWidget {
  const AppDialogScope({required super.child, super.key});

  @override
  bool updateShouldNotify(AppDialogScope oldWidget) => false;
}

/// 提供一致標題、圖示、內容與操作列的標準 dialog 外殼。
///
/// [accent] 為選色、人物、標籤等表單使用的漸層底色與邊框。
/// 標題列右上角預設有關閉 X；[leading] 放在操作列左下角，與取消、確認同列。
class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    required this.title,
    required this.content,
    this.icon,
    this.titleTrailing,
    this.leading,
    this.actions = const <Widget>[],
    this.accent = false,
    this.fillHeight = false,
    this.showClose = true,
    this.onClose,
    this.closeEnabled = true,
    super.key,
  });

  final String title;
  final Widget content;
  final Widget? icon;
  final Widget? titleTrailing;
  final Widget? leading;
  final List<Widget> actions;
  final bool accent;

  /// 卡片直接用到可用高度的 90%。內容在這層裡捲動，短內容不會把卡片縮短。
  final bool fillHeight;

  /// 必選或強制流程（例如新手導覽、還原金鑰）設為 false，不提供右上角關閉。
  final bool showClose;

  /// 關閉 X 的行為；未指定時直接關閉 dialog。
  final VoidCallback? onClose;

  /// 儲存或刪除中停用 X，避免操作進行到一半被關掉。
  final bool closeEnabled;

  Widget _contentSlot(Widget child) {
    final Widget scoped = AppDialogScope(child: child);
    if (!fillHeight) return scoped;
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: scoped,
    );
  }

  Widget _actionBar() {
    if (leading == null) {
      return OverflowBar(
        alignment: MainAxisAlignment.end,
        spacing: 8,
        overflowSpacing: 8,
        overflowAlignment: OverflowBarAlignment.end,
        children: actions,
      );
    }
    // 外層 Wrap 讓 leading 與按鈕組同列；放不下時整組按鈕換到下一行，
    // 避免 leading 吃掉寬度把按鈕擠扁。內層 Wrap 依內容寬度計算，才能判斷是否放得下。
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          leading!,
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget? closeButton = showClose
        ? IconButton(
            tooltip: context.l10n.commonCloseTooltip,
            onPressed: closeEnabled
                ? (onClose ?? () => Navigator.of(context).pop())
                : null,
            icon: const Icon(Icons.close_rounded),
          )
        : null;
    final Widget titleRow = Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[icon!, const SizedBox(width: 12)],
        Expanded(child: Text(title)),
        if (titleTrailing != null) ...<Widget>[
          const SizedBox(width: 8),
          titleTrailing!,
        ],
        if (closeButton != null) ...<Widget>[
          const SizedBox(width: 8),
          closeButton,
        ],
      ],
    );
    if (!accent) {
      return AlertDialog(
        insetPadding: EdgeInsets.zero,
        constraints: appDialogConstraints(context, fillHeight: fillHeight),
        titlePadding: AppDialogInsets.title,
        contentPadding: AppDialogInsets.content,
        actionsPadding: AppDialogInsets.actions,
        title: titleRow,
        content: _contentSlot(content),
        actions: leading == null ? actions : <Widget>[_actionBar()],
      );
    }
    // Dialog 的外層會撐滿路由。漸層必須畫在卡片內容上，否則短內容也會鋪滿螢幕。
    final colors = context.appColors;
    final TextStyle titleStyle =
        DialogTheme.of(context).titleTextStyle ??
        Theme.of(context).textTheme.titleLarge!;
    return Dialog(
      insetPadding: EdgeInsets.zero,
      constraints: appDialogConstraints(context, fillHeight: fillHeight),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.none,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colors.accentDialogGradientStart,
              colors.accentDialogGradientEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.accentDialogBorder),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: AppDialogInsets.title,
              child: DefaultTextStyle(style: titleStyle, child: titleRow),
            ),
            Flexible(
              child: Padding(
                padding: AppDialogInsets.content,
                child: _contentSlot(content),
              ),
            ),
            if (actions.isNotEmpty || leading != null)
              Padding(padding: AppDialogInsets.actions, child: _actionBar()),
          ],
        ),
      ),
    );
  }
}

/// 二元確認操作的按鈕語意。
enum AppConfirmStyle { primary, destructive }

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    required this.title,
    required this.content,
    required this.cancelLabel,
    required this.confirmLabel,
    this.confirmStyle = AppConfirmStyle.primary,
    this.icon,
    super.key,
  });

  final String title;
  final Widget content;
  final String cancelLabel;
  final String confirmLabel;
  final AppConfirmStyle confirmStyle;
  final Widget? icon;

  @override
  Widget build(BuildContext context) => AppDialogShell(
    title: title,
    content: content,
    icon: icon,
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(cancelLabel),
      ),
      switch (confirmStyle) {
        AppConfirmStyle.primary => FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
        AppConfirmStyle.destructive => FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: Text(confirmLabel),
        ),
      },
    ],
  );
}

/// 顯示二元確認 dialog，預設使用較緊湊的 80% 寬度；關閉或取消時回傳 `false`。
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required Widget content,
  required String cancelLabel,
  required String confirmLabel,
  AppConfirmStyle confirmStyle = AppConfirmStyle.primary,
  AppDialogSize size = AppDialogSize.compact,
  Widget? icon,
}) async =>
    await showAppDialog<bool>(
      context: context,
      size: size,
      builder: (_) => AppConfirmDialog(
        title: title,
        content: content,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
        confirmStyle: confirmStyle,
        icon: icon,
      ),
    ) ??
    false;
