import 'package:material_ui/material_ui.dart';

/// AI 視窗沿用既有藍灰色階，不改動全域主題。
class AiSettingsTheme extends StatelessWidget {
  const AiSettingsTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness != Brightness.dark) return child;
    final colors = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        dialogTheme: theme.dialogTheme.copyWith(
          backgroundColor: colors.surfaceContainerHigh,
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          fillColor: colors.surfaceContainer,
        ),
      ),
      child: child,
    );
  }
}
