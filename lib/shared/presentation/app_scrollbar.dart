import 'package:flutter/material.dart';

/// 全站主 scrollbar 樣式（首頁、設定系長頁）。
const ScrollbarThemeData kAppScrollbarTheme = ScrollbarThemeData(
  thumbVisibility: WidgetStatePropertyAll<bool>(true),
  interactive: true,
  thickness: WidgetStatePropertyAll<double>(4),
  radius: Radius.circular(4),
  crossAxisMargin: 0,
  mainAxisMargin: 4,
);

/// 卡片內嵌套列表用，刻意比主 scrollbar 更細。
const ScrollbarThemeData kNestedPanelScrollbarTheme = ScrollbarThemeData(
  thumbVisibility: WidgetStatePropertyAll<bool>(true),
  interactive: true,
  thickness: WidgetStatePropertyAll<double>(3),
  radius: Radius.circular(3),
  crossAxisMargin: 2,
  mainAxisMargin: 2,
);

class ListViewWithScrollbar extends StatefulWidget {
  const ListViewWithScrollbar({
    required this.padding,
    required this.children,
    super.key,
  });

  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  @override
  State<ListViewWithScrollbar> createState() => _ListViewWithScrollbarState();
}

class _ListViewWithScrollbarState extends State<ListViewWithScrollbar> {
  late final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets resolved = widget.padding.resolve(
      Directionality.of(context),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        resolved.left,
        resolved.top,
        resolved.right,
        0,
      ),
      child: Scrollbar(
        controller: _controller,
        child: ListView(
          controller: _controller,
          padding: EdgeInsets.only(bottom: resolved.bottom),
          children: widget.children,
        ),
      ),
    );
  }
}

class NestedPanelScrollbar extends StatelessWidget {
  const NestedPanelScrollbar({
    required this.controller,
    required this.child,
    this.contentPadding,
    super.key,
  });

  final ScrollController controller;
  final Widget child;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(
        context,
      ).copyWith(scrollbarTheme: kNestedPanelScrollbarTheme),
      child: Scrollbar(
        controller: controller,
        child: SingleChildScrollView(
          controller: controller,
          padding: contentPadding,
          child: child,
        ),
      ),
    );
  }
}
