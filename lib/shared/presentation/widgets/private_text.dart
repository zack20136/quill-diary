import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/shared/presentation/private_text_spans.dart';

/// 按實際行高繪製隱藏底色，避免混合字型的字面高度不同。
class PrivateText extends SingleChildRenderObjectWidget {
  PrivateText({super.key, required this.text, required this.ranges, this.style})
    : super(
        child: Text.rich(TextSpan(text: text), style: style),
      );

  PrivateText.rich(TextSpan span, {super.key, required this.ranges, this.style})
    : text = span.toPlainText(),
      super(child: Text.rich(span, style: style));

  final String text;
  final List<PrivateTextRange> ranges;
  final TextStyle? style;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderPrivateText(
    mergePrivateRanges(ranges, text.length),
    privateTextHighlight(Theme.of(context).colorScheme),
  );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderPrivateText renderObject,
  ) {
    renderObject
      ..ranges = mergePrivateRanges(ranges, text.length)
      ..color = privateTextHighlight(Theme.of(context).colorScheme);
  }
}

class RenderPrivateText extends RenderProxyBox {
  RenderPrivateText(this._ranges, this._color);

  List<PrivateTextRange> _ranges;
  Color _color;

  set ranges(List<PrivateTextRange> value) {
    _ranges = value;
    markNeedsPaint();
  }

  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  RenderParagraph? _paragraph(RenderObject object) {
    if (object is RenderParagraph) return object;
    RenderParagraph? result;
    object.visitChildren((child) => result ??= _paragraph(child));
    return result;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final paragraph = child == null ? null : _paragraph(child!);
    if (paragraph != null && _ranges.isNotEmpty) {
      final transform = paragraph.getTransformTo(this);
      final path = Path();
      for (final range in _ranges) {
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: range.start, extentOffset: range.end),
          boxHeightStyle: ui.BoxHeightStyle.max,
        );
        for (final box in boxes) {
          path.addRect(
            MatrixUtils.transformRect(transform, box.toRect()).shift(offset),
          );
        }
      }
      context.canvas.drawPath(path, Paint()..color = _color);
    }
    super.paint(context, offset);
  }
}
