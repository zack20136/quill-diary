import 'package:flutter/material.dart';

const Duration kEditorChromeEnterDuration = Duration(milliseconds: 180);
const Duration kEditorChromeExitDuration = Duration(milliseconds: 120);

const Key kEditorAttachmentAreaVisibleKey = Key(
  'editor-attachment-area-visible',
);
const Key kEditorAttachmentAreaHiddenKey = Key('editor-attachment-area-hidden');

Widget editorKeyboardChromeTransition(
  Widget child,
  Animation<double> animation,
) {
  final Animation<double> curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curved,
    child: SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.14),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    ),
  );
}
