import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// 復原金鑰輸入欄位：預設遮罩、可切換顯示，並關閉建議與自動填入。
class RecoveryKeyTextField extends StatefulWidget {
  const RecoveryKeyTextField({
    required this.controller,
    this.autofocus = false,
    this.errorText,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final bool autofocus;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;

  @override
  State<RecoveryKeyTextField> createState() => _RecoveryKeyTextFieldState();
}

class _RecoveryKeyTextFieldState extends State<RecoveryKeyTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      autofillHints: const <String>[],
      obscureText: _obscured,
      keyboardType: TextInputType.visiblePassword,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontFamily: 'monospace',
        letterSpacing: 1.2,
      ),
      decoration: InputDecoration(
        labelText: l10n.settingsRecoveryKeyFieldLabel,
        hintText: l10n.settingsRecoveryKeyFieldHint,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          tooltip: _obscured
              ? l10n.settingsRecoveryKeyShowTooltip
              : l10n.settingsRecoveryKeyHideTooltip,
          onPressed: () => setState(() => _obscured = !_obscured),
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      onSubmitted: widget.onSubmitted,
    );
  }
}
