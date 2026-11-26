import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';

/// 按實際行高繪製隱藏底色，避免混合字型的字面高度不同。
class PrivateText extends SingleChildRenderObjectWidget {
  PrivateText({
    super.key,
    required this.text,
    required this.ranges,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  }) : super(
         child: Text.rich(
           TextSpan(text: text),
           style: style,
           maxLines: maxLines,
           overflow: overflow,
         ),
       );

  PrivateText.rich(
    TextSpan span, {
    super.key,
    required this.ranges,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  }) : text = span.toPlainText(),
       super(
         child: Text.rich(
           span,
           style: style,
           maxLines: maxLines,
           overflow: overflow,
         ),
       );

  final String text;
  final List<PrivateTextRange> ranges;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderPrivateText(
    mergePrivateRanges(ranges, text.length),
    context.appColors.privateTextHighlight,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderPrivateText renderObject,
  ) {
    renderObject
      ..ranges = mergePrivateRanges(ranges, text.length)
      ..color = context.appColors.privateTextHighlight;
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
