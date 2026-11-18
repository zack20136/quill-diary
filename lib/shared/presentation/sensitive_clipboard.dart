import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/app_identifiers.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';

abstract final class SensitiveClipboard {
  static const _channel = MethodChannel(
    AppIdentifiers.sensitiveClipboardChannel,
  );

  static Future<bool> copy(
    BuildContext context,
    String text, {
    bool showSuccess = false,
  }) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod<void>('copy', {'text': text});
      } else {
        await Clipboard.setData(ClipboardData(text: text));
      }
    } on Object {
      if (context.mounted) {
        showAppFeedbackToast(
          context,
          context.l10n.commonClipboardWriteFailed,
          tone: AppFeedbackTone.error,
        );
      }
      return false;
    }
    if (showSuccess && context.mounted) {
      showAppFeedbackToast(
        context,
        context.l10n.commonCopiedToClipboard,
        tone: AppFeedbackTone.success,
      );
    }
    return true;
  }

  static Widget contextMenu(BuildContext context, EditableTextState state) {
    final items = state.contextMenuButtonItems.map((item) {
      if (item.type != ContextMenuButtonType.copy &&
          item.type != ContextMenuButtonType.cut) {
        return item;
      }
      return ContextMenuButtonItem(
        type: item.type,
        label: item.label,
        onPressed: () async {
          final value = state.textEditingValue;
          final copied = await copy(
            context,
            value.selection.textInside(value.text),
          );
          if (!copied || !state.mounted) return;
          if (item.type == ContextMenuButtonType.cut &&
              state.textEditingValue == value) {
            state.userUpdateTextEditingValue(
              TextEditingValue(
                text:
                    value.selection.textBefore(value.text) +
                    value.selection.textAfter(value.text),
                selection: TextSelection.collapsed(
                  offset: value.selection.start,
                ),
              ),
              SelectionChangedCause.toolbar,
            );
          }
          state.hideToolbar();
        },
      );
    }).toList();
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }
}
