import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/l10n/l10n.dart';

/// 把復原金鑰整理成每四碼一組。橫線由欄位補上，貼上已有的橫線也收成同一格式。
class RecoveryKeyInputFormatter extends TextInputFormatter {
  const RecoveryKeyInputFormatter();

  static const int payloadLength = 24;
  static const int groupSize = 4;

  static final RegExp _nonPayload = RegExp('[^A-Z0-9]');

  static String _payloadOf(String text) {
    final String upper = text.toUpperCase().replaceAll(_nonPayload, '');
    if (upper.length <= payloadLength) return upper;
    return upper.substring(0, payloadLength);
  }

  static String _formatPayload(String payload) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < payload.length; i++) {
      if (i > 0 && i % groupSize == 0) buffer.write('-');
      buffer.write(payload[i]);
    }
    return buffer.toString();
  }

  static int _payloadCountBefore(String text, int offset) {
    final int end = offset < 0 ? text.length : offset.clamp(0, text.length);
    return _payloadOf(text.substring(0, end)).length;
  }

  static int _formattedOffset(int payloadCount) {
    if (payloadCount <= 0) return 0;
    final int count = payloadCount.clamp(0, payloadLength);
    return count + ((count - 1) ~/ groupSize);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String oldPayload = _payloadOf(oldValue.text);
    String payload = _payloadOf(newValue.text);
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
      text: _formatPayload(payload),
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
      inputFormatters: const <TextInputFormatter>[RecoveryKeyInputFormatter()],
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
