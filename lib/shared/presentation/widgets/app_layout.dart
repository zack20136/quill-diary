import 'package:flutter/widgets.dart';

/// 共用內容寬度規則：以父容器為基準保留比例留白，並限制寬螢幕寬度。
class AppResponsiveWidth extends StatelessWidget {
  const AppResponsiveWidth({
    required this.child,
    this.widthFactor = 0.9,
    this.maxWidth,
    super.key,
  }) : assert(widthFactor > 0 && widthFactor <= 1);

  final Widget child;
  final double widthFactor;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double availableWidth = constraints.maxWidth;
      final double width = maxWidth == null
          ? availableWidth * widthFactor
          : (availableWidth * widthFactor).clamp(0, maxWidth!);
      return SizedBox(width: width, child: child);
    },
  );
}
