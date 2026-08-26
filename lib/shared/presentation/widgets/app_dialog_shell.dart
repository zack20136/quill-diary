import 'package:flutter/material.dart';

/// Dialog 的可見寬度尺寸。
enum AppDialogSize { standard, compact }

/// 將各種 dialog 的實際寬度統一為對應層級比例。
class _AppDialogWidth extends StatelessWidget {
  const _AppDialogWidth({required this.child, required this.size});

  final Widget child;
  final AppDialogSize size;

  double get _widthFactor => switch (size) {
    AppDialogSize.standard => 0.9,
    AppDialogSize.compact => 0.8,
  };

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: _widthFactor,
    child: SizedBox(width: double.infinity, child: child),
  );
}

/// 以一致的寬度規則建立 Material dialog route。
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  AppDialogSize size = AppDialogSize.standard,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useSafeArea = true,
}) => showDialog<T>(
  context: context,
  builder: (BuildContext dialogContext) =>
      _AppDialogWidth(size: size, child: builder(dialogContext)),
  barrierDismissible: barrierDismissible,
  barrierColor: barrierColor,
  useSafeArea: useSafeArea,
);

/// 提供一致標題、圖示、內容與操作列的標準 dialog 外殼。
class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    required this.title,
    required this.content,
    this.icon,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final Widget content;
  final Widget? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: double.infinity),
    title: Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[icon!, const SizedBox(width: 12)],
        Expanded(child: Text(title)),
      ],
    ),
    content: content,
    actions: actions,
  );
}

/// 二元確認操作的按鈕語意。
enum AppConfirmStyle { primary, destructive }

/// 統一取消與確認操作的標準 dialog。
class _AppConfirmDialog extends StatelessWidget {
  const _AppConfirmDialog({
    required this.title,
    required this.content,
    required this.cancelLabel,
    required this.confirmLabel,
    this.confirmStyle = AppConfirmStyle.primary,
    this.icon,
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
      builder: (_) => _AppConfirmDialog(
        title: title,
        content: content,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
        confirmStyle: confirmStyle,
        icon: icon,
      ),
    ) ??
    false;
