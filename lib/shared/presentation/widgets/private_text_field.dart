import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/private_text_controller.dart';

class PrivateTextField extends StatefulWidget {
  const PrivateTextField({
    required this.controller,
    this.fieldKey,
    this.focusNode,
    this.scrollController,
    this.textInputAction,
    this.keyboardType,
    this.style,
    this.textAlignVertical,
    this.decoration = const InputDecoration(),
    this.enabled = true,
    this.readOnly = false,
    this.expands = false,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    super.key,
  });

  final TextEditingController controller;
  final Key? fieldKey;
  final FocusNode? focusNode;
  final ScrollController? scrollController;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final TextStyle? style;
  final TextAlignVertical? textAlignVertical;
  final InputDecoration decoration;
  final bool enabled;
  final bool readOnly;
  final bool expands;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  @override
  State<PrivateTextField> createState() => _PrivateTextFieldState();
}

class _PrivateTextFieldState extends State<PrivateTextField> {
  _PrivateTextFieldPainter? _painter;
  RenderEditable? _editable;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isPrivate = controller is PrivateTextController;
    if (isPrivate || _editable != null) {
      final color = context.appColors.privateTextHighlight;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final controller = widget.controller;
        final editable = controller is PrivateTextController
            ? _findEditable(context.findRenderObject())
            : null;
        if (!identical(_editable, editable)) {
          _detachPainter();
          _editable = editable;
        }
        if (editable != null && controller is PrivateTextController) {
          final painter = _painter ??= _PrivateTextFieldPainter();
          painter.update(controller, editable.offset, color);
          if (!identical(editable.painter, painter)) editable.painter = painter;
        }
      });
    }

    return TextField(
      key: widget.fieldKey,
      controller: controller,
      selectionHeightStyle: isPrivate ? ui.BoxHeightStyle.max : null,
      selectionWidthStyle: isPrivate ? ui.BoxWidthStyle.tight : null,
      focusNode: widget.focusNode,
      scrollController: widget.scrollController,
      textInputAction: widget.textInputAction,
      keyboardType: widget.keyboardType,
      style: widget.style,
      textAlignVertical: widget.textAlignVertical,
      decoration: widget.decoration,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      expands: widget.expands,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
    );
  }

  RenderEditable? _findEditable(RenderObject? renderObject) {
    if (renderObject is RenderEditable) return renderObject;
    RenderEditable? editable;
    renderObject?.visitChildren((child) => editable ??= _findEditable(child));
    return editable;
  }

  void _detachPainter() {
    final editable = _editable;
    if (editable != null && editable.attached && editable.painter == _painter) {
      editable.painter = null;
    }
    _editable = null;
    _painter?.dispose();
    _painter = null;
  }

  @override
  void dispose() {
    _detachPainter();
    super.dispose();
  }
}

class _PrivateTextFieldPainter extends RenderEditablePainter {
  PrivateTextController? _controller;
  ViewportOffset? _offset;
  late Color _color;

  void update(
    PrivateTextController controller,
    ViewportOffset offset,
    Color color,
  ) {
    if (!identical(_controller, controller)) {
      _controller?.removeListener(notifyListeners);
      _controller = controller..addListener(notifyListeners);
    }
    if (!identical(_offset, offset)) {
      _offset?.removeListener(notifyListeners);
      _offset = offset..addListener(notifyListeners);
    }
    _color = color;
    notifyListeners();
  }

  @override
  void paint(Canvas canvas, Size size, RenderEditable renderEditable) {
    final ranges = _controller!.highlightRanges;
    if (ranges.isEmpty) return;
    final viewport = Offset.zero & size;
    final path = Path();
    for (final range in ranges) {
      final boxes = renderEditable.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
      );
      for (final box in boxes) {
        final rect = box.toRect().intersect(viewport);
        if (!rect.isEmpty) path.addRect(rect);
      }
    }
    canvas.drawPath(path, Paint()..color = _color);
  }

  @override
  bool shouldRepaint(RenderEditablePainter? oldDelegate) => oldDelegate != this;

  @override
  void dispose() {
    _controller?.removeListener(notifyListeners);
    _offset?.removeListener(notifyListeners);
    super.dispose();
  }
}
