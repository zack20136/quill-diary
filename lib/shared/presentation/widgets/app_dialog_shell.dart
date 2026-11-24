import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_section.dart';

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
/// 標題列右上角預設有關閉 X；[leading] 放在操作列左下角，與取消、確認同列。
class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    required this.title,
    required this.content,
    this.icon,
    this.titleTrailing,
    this.leading,
    this.actions = const <Widget>[],
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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compactTitle = media.size.width < media.textScaler.scale(310);
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
        Expanded(
          child: compactTitle
              ? Tooltip(
                  message: title,
                  excludeFromSemantics: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Text(title),
        ),
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
    return AlertDialog(
      insetPadding: EdgeInsets.zero,
      constraints: appDialogConstraints(context, fillHeight: fillHeight),
      titlePadding: AppDialogInsets.title,
      contentPadding: AppDialogInsets.content,
      actionsPadding: AppDialogInsets.actions,
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actionsOverflowButtonSpacing: 8,
      title: titleRow,
      content: _contentSlot(content),
      actions: switch (leading) {
        null => actions,
        final Widget leading => [
          _DialogActionLayout(
            children: [
              leading,
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ),
        ],
      },
    );
  }
}

class _DialogActionLayout extends MultiChildRenderObjectWidget {
  const _DialogActionLayout({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDialogActionLayout(Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDialogActionLayout renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _DialogActionParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderDialogActionLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DialogActionParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DialogActionParentData> {
  _RenderDialogActionLayout(this._textDirection);

  static const double _gap = 8;
  TextDirection _textDirection;

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DialogActionParentData) {
      child.parentData = _DialogActionParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    firstChild!.getMinIntrinsicWidth(height),
    lastChild!.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      firstChild!.getMaxIntrinsicWidth(height) +
      _gap +
      lastChild!.getMaxIntrinsicWidth(height);

  ({Size size, bool stacked}) _measure(
    BoxConstraints constraints,
    Size leading,
    Size trailing,
  ) {
    final totalWidth = leading.width + _gap + trailing.width;
    final stacked = totalWidth > constraints.maxWidth;
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : totalWidth;
    final height = stacked
        ? leading.height + _gap + trailing.height
        : math.max(leading.height, trailing.height);
    return (size: constraints.constrain(Size(width, height)), stacked: stacked);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final available = constraints.loosen();
    return _measure(
      constraints,
      firstChild!.getDryLayout(available),
      lastChild!.getDryLayout(available),
    ).size;
  }

  @override
  void performLayout() {
    final available = constraints.loosen();
    final leading = firstChild!..layout(available, parentUsesSize: true);
    final trailing = lastChild!..layout(available, parentUsesSize: true);
    final result = _measure(constraints, leading.size, trailing.size);
    size = result.size;
    final rtl = _textDirection == TextDirection.rtl;
    (leading.parentData! as _DialogActionParentData).offset = Offset(
      rtl ? size.width - leading.size.width : 0,
      result.stacked ? 0 : (size.height - leading.size.height) / 2,
    );
    (trailing.parentData! as _DialogActionParentData).offset = Offset(
      rtl ? 0 : size.width - trailing.size.width,
      result.stacked
          ? leading.size.height + _gap
          : (size.height - trailing.size.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class AppConfirmationCheckbox extends StatelessWidget {
  const AppConfirmationCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return MergeSemantics(
      child: Semantics(
        checked: value,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                spacing: 8,
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      value
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      key: ValueKey<bool>(value),
                      size: 24,
                      color: value
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    this.wrapContent = true,
    super.key,
  });

  final String title;
  final Widget content;
  final String cancelLabel;
  final String confirmLabel;
  final AppConfirmStyle confirmStyle;
  final Widget? icon;
  final bool wrapContent;

  @override
  Widget build(BuildContext context) => AppDialogShell(
    title: title,
    content: AppScrollView(
      child: wrapContent
          ? AppDialogSection(padding: const EdgeInsets.all(12), child: content)
          : content,
    ),
    icon: icon,
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(cancelLabel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        style: confirmStyle == AppConfirmStyle.destructive
            ? FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              )
            : null,
        child: Text(confirmLabel),
      ),
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
  bool wrapContent = true,
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
        wrapContent: wrapContent,
      ),
    ) ??
    false;
