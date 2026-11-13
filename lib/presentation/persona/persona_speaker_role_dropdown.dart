import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_menu_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';

/// 分身匯入共用的下拉欄位，外觀對齊 Thinking 選單。
class PersonaDropdownField<T> extends StatefulWidget {
  const PersonaDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.label,
  });

  final T value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T> onChanged;
  final String? label;

  @override
  State<PersonaDropdownField<T>> createState() =>
      _PersonaDropdownFieldState<T>();
}

class _PersonaDropdownFieldState<T> extends State<PersonaDropdownField<T>> {
  final _fieldFocus = FocusNode();
  final _menuFocus = FocusNode();

  @override
  void dispose() {
    _fieldFocus.dispose();
    _menuFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final label = widget.label;
    final value = widget.value;
    final menuWidth = (MediaQuery.sizeOf(context).width - 48).clamp(
      160.0,
      320.0,
    );
    return MenuAnchor(
      childFocusNode: _fieldFocus,
      onOpen: _menuFocus.requestFocus,
      crossAxisUnconstrained: false,
      alignmentOffset: const Offset(0, 4),
      style: appMenuStyle(context, width: menuWidth),
      menuChildren: [
        for (final item in widget.items)
          MenuItemButton(
            overflowAxis: Axis.vertical,
            focusNode: item == value ? _menuFocus : null,
            onPressed: () => widget.onChanged(item),
            style: appMenuItemStyle(context, selected: item == value),
            trailingIcon: item == value
                ? const Icon(Icons.check, size: 18)
                : null,
            child: SizedBox(
              width: double.infinity,
              child: Text(widget.itemLabel(item)),
            ),
          ),
      ],
      builder: (context, controller, child) => InkWell(
        focusNode: _fieldFocus,
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 26),
          padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? colors.surfaceContainer
                : colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  widget.itemLabel(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PersonaSpeakerRoleCard extends StatelessWidget {
  const PersonaSpeakerRoleCard({
    super.key,
    required this.label,
    required this.role,
    required this.onChanged,
  });

  final String label;
  final PersonaSpeakerRole role;
  final ValueChanged<PersonaSpeakerRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.secondary.withValues(alpha: 0.14),
            foregroundColor: colors.secondary,
            child: Icon(personaSpeakerRoleIcon(role), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          PersonaDropdownField<PersonaSpeakerRole>(
            value: role,
            items: PersonaSpeakerRole.values,
            itemLabel: (item) => personaSpeakerRoleLabel(context.l10n, item),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

String personaSpeakerRoleLabel(
  AppLocalizations l10n,
  PersonaSpeakerRole role,
) => switch (role) {
  PersonaSpeakerRole.user => l10n.personaRoleUser,
  PersonaSpeakerRole.personaSubject => l10n.personaRoleSubject,
  PersonaSpeakerRole.other => l10n.personaRoleOther,
  PersonaSpeakerRole.unknown => l10n.personaRoleUnknown,
};

IconData personaSpeakerRoleIcon(PersonaSpeakerRole role) => switch (role) {
  PersonaSpeakerRole.user => Icons.person_outline,
  PersonaSpeakerRole.personaSubject => Icons.face_outlined,
  PersonaSpeakerRole.other => Icons.people_outline,
  PersonaSpeakerRole.unknown => Icons.block_outlined,
};
