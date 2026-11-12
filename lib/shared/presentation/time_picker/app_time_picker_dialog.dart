import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

Future<TimeOfDay?> showAppTimePickerDialog({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? title,
}) => showAppDialog<TimeOfDay>(
  context: context,
  builder: (_) => _AppTimePickerDialog(
    initialTime: initialTime,
    title: title ?? context.l10n.timePickerChooseTime,
  ),
);

enum _TimePickerField { hour, minute }

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _AppTimePickerDialog extends StatefulWidget {
  const _AppTimePickerDialog({required this.initialTime, required this.title});

  final TimeOfDay initialTime;
  final String title;

  @override
  State<_AppTimePickerDialog> createState() => _AppTimePickerDialogState();
}

class _AppTimePickerDialogState extends State<_AppTimePickerDialog> {
  late int _hour24 = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;
  _TimePickerField _field = _TimePickerField.hour;

  bool get _isPm => _hour24 >= 12;
  int get _hour12 {
    final int value = _hour24 % 12;
    return value == 0 ? 12 : value;
  }

  void _setPeriod(bool pm) {
    setState(() => _hour24 = (_hour12 % 12) + (pm ? 12 : 0));
  }

  void _setHour12(int hour) {
    setState(() => _hour24 = (hour % 12) + (_isPm ? 12 : 0));
  }

  void _setMinute(int minute) {
    setState(() => _minute = minute);
  }

  void _apply() {
    Navigator.of(context).pop(TimeOfDay(hour: _hour24, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      title: widget.title,
      content: AppScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TimeHeader(
              hour: _hour12,
              minute: _minute,
              isPm: _isPm,
              field: _field,
              onPeriodChanged: _setPeriod,
              onFieldChanged: (_TimePickerField value) {
                setState(() => _field = value);
              },
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double dialSize = math.min(
                  constraints.maxWidth,
                  MediaQuery.sizeOf(context).height < 600 ? 218 : 252,
                );
                return _TimeDial(
                  key: const Key('app-time-picker-dial'),
                  size: dialSize,
                  field: _field,
                  hour: _hour12,
                  minute: _minute,
                  onHourChanged: _setHour12,
                  onHourSelectionComplete: () {
                    setState(() => _field = _TimePickerField.minute);
                  },
                  onMinuteChanged: _setMinute,
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('app-time-picker-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonActionCancel),
        ),
        FilledButton(
          key: const Key('app-time-picker-confirm'),
          onPressed: _apply,
          child: Text(context.l10n.commonActionConfirm),
        ),
      ],
    );
  }
}

class _TimeHeader extends StatelessWidget {
  const _TimeHeader({
    required this.hour,
    required this.minute,
    required this.isPm,
    required this.field,
    required this.onPeriodChanged,
    required this.onFieldChanged,
  });

  final int hour;
  final int minute;
  final bool isPm;
  final _TimePickerField field;
  final ValueChanged<bool> onPeriodChanged;
  final ValueChanged<_TimePickerField> onFieldChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _PeriodSelector(isPm: isPm, onChanged: onPeriodChanged),
        const SizedBox(width: 10),
        Expanded(
          child: _TimeValueControl(
            key: const Key('app-time-picker-hour'),
            selected: field == _TimePickerField.hour,
            value: _twoDigits(hour),
            semanticLabel: context.l10n.timePickerHourLabel,
            onTap: () => onFieldChanged(_TimePickerField.hour),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(
            ':',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: _TimeValueControl(
            key: const Key('app-time-picker-minute'),
            selected: field == _TimePickerField.minute,
            value: _twoDigits(minute),
            semanticLabel: context.l10n.timePickerMinuteLabel,
            onTap: () => onFieldChanged(_TimePickerField.minute),
          ),
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.isPm, required this.onChanged});

  final bool isPm;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    Widget option({required bool pm, required String label}) {
      final bool selected = isPm == pm;
      return Expanded(
        child: Material(
          color: selected ? colors.primaryContainer : Colors.transparent,
          child: InkWell(
            key: Key(pm ? 'app-time-picker-pm' : 'app-time-picker-am'),
            onTap: () => onChanged(pm),
            splashColor: colors.primary.withValues(alpha: 0.18),
            highlightColor: colors.primary.withValues(alpha: 0.08),
            child: Semantics(
              selected: selected,
              button: true,
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 48,
      height: 80,
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            option(pm: false, label: context.l10n.timePickerAm),
            Divider(height: 1, color: colors.outlineVariant),
            option(pm: true, label: context.l10n.timePickerPm),
          ],
        ),
      ),
    );
  }
}

class _TimeValueControl extends StatelessWidget {
  const _TimeValueControl({
    required this.selected,
    required this.value,
    required this.semanticLabel,
    required this.onTap,
    super.key,
  });

  final bool selected;
  final String value;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = selected
        ? colors.primaryContainer
        : colors.surfaceContainerLow;
    final Color foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurface;
    final TextStyle? textStyle = Theme.of(context).textTheme.displaySmall
        ?.copyWith(color: foreground, fontWeight: FontWeight.w500, height: 1);

    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      child: SizedBox(
        height: 80,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: textStyle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeDial extends StatelessWidget {
  const _TimeDial({
    required this.size,
    required this.field,
    required this.hour,
    required this.minute,
    required this.onHourChanged,
    required this.onHourSelectionComplete,
    required this.onMinuteChanged,
    super.key,
  });

  final double size;
  final _TimePickerField field;
  final int hour;
  final int minute;
  final ValueChanged<int> onHourChanged;
  final VoidCallback onHourSelectionComplete;
  final ValueChanged<int> onMinuteChanged;

  int _valueFor(Offset localPosition, int divisions) {
    final Offset center = Offset(size / 2, size / 2);
    final Offset delta = localPosition - center;
    final double normalized =
        (math.atan2(delta.dy, delta.dx) + math.pi / 2 + math.pi * 2) %
        (math.pi * 2);
    return (normalized / (math.pi * 2) * divisions).round() % divisions;
  }

  void _updateFromTap(Offset position) {
    if (field == _TimePickerField.hour) {
      final int value = _valueFor(position, 12);
      onHourChanged(value == 0 ? 12 : value);
    } else {
      onMinuteChanged(_valueFor(position, 12) * 5);
    }
  }

  void _updateFromDrag(Offset position) {
    if (field == _TimePickerField.hour) {
      final int value = _valueFor(position, 12);
      onHourChanged(value == 0 ? 12 : value);
    } else {
      onMinuteChanged(_valueFor(position, 60));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final int selectedIndex = field == _TimePickerField.hour
        ? hour % 12
        : minute;
    final List<int> labels = field == _TimePickerField.hour
        ? <int>[12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        : List<int>.generate(12, (int index) => index * 5);
    final double labelRadius = size / 2 - 25;

    void completeHourSelection() {
      if (field == _TimePickerField.hour) onHourSelectionComplete();
    }

    return Semantics(
      label: context.l10n.timePickerDialSemantics,
      value: field == _TimePickerField.hour
          ? '$hour'
          : _twoDigits(minute),
      child: SizedBox.square(
        dimension: size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (TapUpDetails details) {
            _updateFromTap(details.localPosition);
            completeHourSelection();
          },
          onPanUpdate: (DragUpdateDetails details) =>
              _updateFromDrag(details.localPosition),
          onPanEnd: (_) => completeHourSelection(),
          child: Stack(
            children: <Widget>[
              CustomPaint(
                size: Size.square(size),
                painter: _TimeDialPainter(
                  selectedIndex: selectedIndex,
                  divisions: field == _TimePickerField.hour ? 12 : 60,
                  backgroundColor: context.appColors.sectionInset,
                  handColor: colors.primary,
                  selectedColor: colors.primary,
                ),
              ),
              for (int index = 0; index < labels.length; index++)
                Positioned(
                  left:
                      size / 2 +
                      math.sin(index / 12 * math.pi * 2) * labelRadius -
                      22,
                  top:
                      size / 2 -
                      math.cos(index / 12 * math.pi * 2) * labelRadius -
                      22,
                  width: 44,
                  height: 44,
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        field == _TimePickerField.minute
                            ? _twoDigits(labels[index])
                            : '${labels[index]}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color:
                              selectedIndex ==
                                  (field == _TimePickerField.hour
                                      ? labels[index] % 12
                                      : labels[index])
                              ? colors.onPrimary
                              : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeDialPainter extends CustomPainter {
  const _TimeDialPainter({
    required this.selectedIndex,
    required this.divisions,
    required this.backgroundColor,
    required this.handColor,
    required this.selectedColor,
  });

  final int selectedIndex;
  final int divisions;
  final Color backgroundColor;
  final Color handColor;
  final Color selectedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    canvas.drawCircle(center, radius, Paint()..color = backgroundColor);
    final double angle = selectedIndex / divisions * math.pi * 2 - math.pi / 2;
    final double handLength = radius - 25;
    final Offset end =
        center + Offset(math.cos(angle), math.sin(angle)) * handLength;
    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = handColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(end, 22, Paint()..color = selectedColor);
    canvas.drawCircle(center, 4, Paint()..color = handColor);
  }

  @override
  bool shouldRepaint(_TimeDialPainter oldDelegate) =>
      selectedIndex != oldDelegate.selectedIndex ||
      divisions != oldDelegate.divisions ||
      backgroundColor != oldDelegate.backgroundColor ||
      handColor != oldDelegate.handColor ||
      selectedColor != oldDelegate.selectedColor;
}
