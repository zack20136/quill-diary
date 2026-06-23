import 'package:flutter/material.dart';

import '../home_layout.dart';

/// 首頁左下返回頂部、右下新增日記等浮動圓形操作按鈕。
class HomeCircleActionButton extends StatelessWidget {
  const HomeCircleActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color iconColor = onPressed == null
        ? cs.onSecondaryContainer.withValues(alpha: 0.38)
        : cs.onSecondaryContainer;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: cs.secondaryContainer,
          elevation: 3,
          shadowColor: cs.shadow.withValues(alpha: 0.18),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: HomeLayout.circleActionSize,
              height: HomeLayout.circleActionSize,
              child: Icon(
                icon,
                color: iconColor,
                size: HomeLayout.circleActionIconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
