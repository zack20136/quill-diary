import 'package:flutter/material.dart';

/// Loading 指示器在頁面、區段與行內使用時的留白規則。
enum AppLoadingStateLayout { page, section, inline }

/// 顯示可選說明文字的共用 loading 狀態。
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    this.layout = AppLoadingStateLayout.section,
    this.message,
    super.key,
  });

  final AppLoadingStateLayout layout;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final double verticalPadding = switch (layout) {
      AppLoadingStateLayout.page => 48,
      AppLoadingStateLayout.section => 18,
      AppLoadingStateLayout.inline => 0,
    };
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CircularProgressIndicator(),
        if (message != null && message!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: content,
      ),
    );
  }
}
