import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/recovery/recovery_key.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/sensitive_clipboard.dart';

/// 把復原金鑰整理成每四碼一組。橫線由欄位補上，貼上已有的橫線也收成同一格式。
class RecoveryKeyInputFormatter extends TextInputFormatter {
  const RecoveryKeyInputFormatter();

  static int _payloadCountBefore(String text, int offset) {
    final int end = offset < 0 ? text.length : offset.clamp(0, text.length);
    return RecoveryKey.payloadOf(text.substring(0, end)).length;
  }

  static int _formattedOffset(int payloadCount) {
    if (payloadCount <= 0) return 0;
    final int count = payloadCount.clamp(0, RecoveryKey.symbolCount);
    return count + ((count - 1) ~/ RecoveryKey.groupSize);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed ||
        !RecoveryKey.isValidPartial(newValue.text)) {
      return newValue;
    }
    final String oldPayload = RecoveryKey.payloadOf(oldValue.text);
    String payload = RecoveryKey.payloadOf(newValue.text);
    final bool collapsed = newValue.selection.isCollapsed;
    int cursor = _payloadCountBefore(
      newValue.text,
      newValue.selection.extentOffset,
    ).clamp(0, payload.length);
    int base = _payloadCountBefore(
      newValue.text,
      newValue.selection.baseOffset,
    ).clamp(0, payload.length);

    // 退格打在自動補上的橫線時，原文沒有少掉有效字元，改刪掉橫線前一個字。
    if (collapsed &&
        newValue.text.length < oldValue.text.length &&
        payload == oldPayload &&
        cursor > 0) {
      payload = payload.substring(0, cursor - 1) + payload.substring(cursor);
      cursor -= 1;
      base = cursor;
    }

    return TextEditingValue(
      text: RecoveryKey.format(payload),
      selection: TextSelection(
        baseOffset: _formattedOffset(base),
        extentOffset: _formattedOffset(cursor),
      ),
    );
  }
}

/// 復原金鑰輸入欄位：預設顯示以便對照分組，可暫時遮住，並關閉建議與自動填入。
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
  bool _obscured = false;
  bool _submittedInvalid = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return TextField(
      controller: widget.controller,
      contextMenuBuilder: SensitiveClipboard.contextMenu,
      autofocus: widget.autofocus,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      autofillHints: const <String>[],
      obscureText: _obscured,
      keyboardType: TextInputType.visiblePassword,
      inputFormatters: const <TextInputFormatter>[RecoveryKeyInputFormatter()],
      style: theme.textTheme.bodyLarge?.copyWith(
        fontFamily: 'monospace',
        letterSpacing: 1.2,
      ),
      decoration: InputDecoration(
        labelText: l10n.settingsRecoveryKeyFieldLabel,
        hintText: l10n.settingsRecoveryKeyFieldHint,
        errorText:
            _submittedInvalid ||
                !RecoveryKey.isValidPartial(widget.controller.text)
            ? l10n.recoveryKeyInvalidInput
            : widget.errorText,
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
      onSubmitted: (value) {
        try {
          widget.onSubmitted?.call(RecoveryKey.normalize(value));
        } on RecoveryKeyFormatException {
          setState(() => _submittedInvalid = true);
        }
      },
      onChanged: (_) => setState(() => _submittedInvalid = false),
    );
  }
}
