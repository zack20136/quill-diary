import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/app_menu_style.dart';

class AppOptionField<T> extends StatefulWidget {
  const AppOptionField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;

  @override
  State<AppOptionField<T>> createState() => _AppOptionFieldState<T>();
}

class _AppOptionFieldState<T> extends State<AppOptionField<T>> {
  final _fieldFocus = FocusNode();
  final _menuFocus = FocusNode();

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final options = widget.options;
    final onChanged = widget.onChanged;
    final selected = options
        .where((option) => option.$1 == value)
        .firstOrNull
        ?.$2;
    final enabled = onChanged != null && options.isNotEmpty;
    final color = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).disabledColor;
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        crossAxisUnconstrained: false,
        childFocusNode: _fieldFocus,
        onOpen: _menuFocus.requestFocus,
        style: appMenuStyle(context, width: constraints.maxWidth),
        menuChildren: [
          for (final (option, text) in options)
            MenuItemButton(
              overflowAxis: Axis.vertical,
              focusNode:
                  option == value ||
                      (selected == null && option == options.first.$1)
                  ? _menuFocus
                  : null,
              onPressed: enabled ? () => onChanged(option) : null,
              style: appMenuItemStyle(context, selected: option == value)
                  .copyWith(
                    minimumSize: WidgetStatePropertyAll(
                      Size(
                        (constraints.maxWidth - 12).clamp(0, double.infinity),
                        40,
                      ),
                    ),
                  ),
              trailingIcon: option == value
                  ? const Icon(Icons.check, size: 18)
                  : null,
              child: SizedBox(width: double.infinity, child: Text(text)),
            ),
        ],
        builder: (context, controller, child) => Semantics(
          button: true,
          enabled: enabled,
          child: InkWell(
            focusNode: _fieldFocus,
            onTap: !enabled
                ? null
                : () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              isEmpty: selected == null,
              decoration: InputDecoration(
                labelText: widget.label,
                enabled: enabled,
                suffixIcon: Icon(Icons.arrow_drop_down, color: color),
              ),
              child: Text(
                selected ?? '',
                style: TextStyle(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fieldFocus.dispose();
    _menuFocus.dispose();
    super.dispose();
  }
}
