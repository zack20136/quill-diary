import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';
import 'package:quill_diary/shared/presentation/date_picker/app_date_picker_dialog.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/people_labels.dart';
import 'package:quill_diary/shared/presentation/person_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/accent_color_wheel_dialog.dart';
import 'package:quill_diary/shared/presentation/widgets/accent_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';

/// 顯示新增／編輯人物表單；儲存成功回傳人物。
Future<Person?> showPersonComposerDialog(
  BuildContext context, {
  PersonId? personId,
  String initialName = '',
}) async {
  final Color barrierColor = context.appColors.scrim;
  return showDialog<Person>(
    context: context,
    barrierDismissible: false,
    barrierColor: barrierColor,
    useSafeArea: false,
    builder: (BuildContext ctx) {
      final bool compact = MediaQuery.sizeOf(ctx).width < 600;
      return SafeArea(
        maintainBottomViewPadding: true,
        child: Builder(
          builder: (BuildContext safeContext) => MediaQuery.removeViewInsets(
            context: safeContext,
            removeBottom: true,
            child: Dialog(
              key: const Key('person-composer-dialog'),
              insetPadding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 24,
                vertical: compact ? 12 : 24,
              ),
              backgroundColor: Colors.transparent,
              child: PersonComposerDialog(
                personId: personId,
                initialName: initialName,
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// 新增／編輯人物；外殼與標籤 Composer 相同。
class PersonComposerDialog extends ConsumerStatefulWidget {
  const PersonComposerDialog({this.personId, this.initialName = '', super.key});

  final PersonId? personId;
  final String initialName;

  bool get isEditing => personId != null;

  @override
  ConsumerState<PersonComposerDialog> createState() =>
      _PersonComposerDialogState();
}

class _PersonComposerDialogState extends ConsumerState<PersonComposerDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _aliasInputCtrl = TextEditingController();
  final TextEditingController _relationshipDescCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  final List<String> _aliases = <String>[];
  final Set<PersonRelationship> _relationships = <PersonRelationship>{};
  FriendlinessLevel _friendliness = FriendlinessLevel.normal;
  int? _accentArgb;
  PersonBirthday? _birthday;
  int? _acquaintanceYear;
  Person? _loaded;
  bool _saving = false;
  bool _hydrated = false;
  bool _editMissingHandled = false;
  String? _aliasInputError;

  @override
  void initState() {
    super.initState();
    if (!widget.isEditing) {
      _nameCtrl.text = widget.initialName.trim();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aliasInputCtrl.dispose();
    _relationshipDescCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _hydrate(Person person) {
    if (_hydrated) {
      return;
    }
    _hydrated = true;
    _loaded = person;
    _nameCtrl.text = person.name;
    _aliases
      ..clear()
      ..addAll(person.aliases);
    _relationshipDescCtrl.text = person.relationshipDescription;
    _notesCtrl.text = person.notes;
    _relationships
      ..clear()
      ..addAll(person.relationships);
    _friendliness = person.friendliness;
    _accentArgb = person.accentArgb;
    _birthday = person.birthday;
    _acquaintanceYear = person.acquaintanceYear;
  }

  void _commitAliasInput() {
    final TextEditingValue inputValue = _aliasInputCtrl.value;
    if (inputValue.composing.isValid && !inputValue.composing.isCollapsed) {
      return;
    }
    final List<String> candidates = inputValue.text
        .split(RegExp(r'[,，\n]'))
        .map((String value) => value.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return;
    }
    final Set<String> known = _aliases.map(normalizePersonName).toSet();
    final List<String> duplicates = <String>[];
    final List<String> additions = <String>[];
    for (final String candidate in candidates) {
      final String key = normalizePersonName(candidate);
      if (known.add(key)) {
        additions.add(candidate);
      } else {
        duplicates.add(candidate);
      }
    }
    setState(() {
      _aliases.addAll(additions);
      _aliasInputError = duplicates.isEmpty
          ? null
          : context.l10n.peopleAliasAlreadyAdded;
    });
    _aliasInputCtrl.value = TextEditingValue(
      text: duplicates.join('，'),
      selection: TextSelection.collapsed(offset: duplicates.join('，').length),
    );
  }

  Future<void> _pickBirthday() async {
    final DateTime now = DateTime.now();
    final AppMonthDay? picked = await showAppMonthDayPickerDialog(
      context: context,
      initialMonth: _birthday?.month ?? now.month,
      initialDay: _birthday?.day ?? now.day,
      title: context.l10n.peoplePickBirthday,
    );
    if (picked != null && mounted) {
      setState(() {
        _birthday = PersonBirthday(month: picked.month, day: picked.day);
      });
    }
  }

  Future<void> _pickAcquaintanceYear() async {
    final DateTime now = DateTime.now();
    final int initialYear = _acquaintanceYear ?? now.year;
    final int? pickedYear = await showAppYearPickerDialog(
      context: context,
      initialYear: initialYear,
      firstYear: 1900,
      lastYear: now.year,
      title: context.l10n.peopleFieldAcquaintanceYear,
    );
    if (pickedYear == null || !mounted) {
      return;
    }
    if (!isValidAcquaintanceYear(pickedYear)) {
      showAppFeedbackToast(
        context,
        context.l10n.peopleSaveFailure(
          context.l10n.peopleFieldAcquaintanceYear,
        ),
      );
      return;
    }
    setState(() => _acquaintanceYear = pickedYear);
  }

  Future<bool> _confirm(
    String title,
    String body, {
    required String confirmLabel,
  }) async {
    return showAppConfirmDialog(
      context: context,
      title: title,
      content: Text(body),
      cancelLabel: context.l10n.commonActionCancel,
      confirmLabel: confirmLabel,
    );
  }

  bool get _hasUnsavedChanges {
    final PersonDraft baseline = _loaded == null
        ? PersonDraft(name: widget.initialName.trim())
        : PersonDraft.fromPerson(_loaded!);
    bool sameList(List<String> left, List<String> right) =>
        left.length == right.length &&
        List<int>.generate(
          left.length,
          (int index) => index,
        ).every((int index) => left[index] == right[index]);
    return _nameCtrl.text.trim() != baseline.name ||
        !sameList(_aliases, baseline.aliases) ||
        !_relationships.containsAll(baseline.relationships) ||
        !baseline.relationships.containsAll(_relationships) ||
        _relationshipDescCtrl.text != baseline.relationshipDescription ||
        _notesCtrl.text != baseline.notes ||
        _friendliness != baseline.friendliness ||
        _accentArgb != baseline.accentArgb ||
        _birthday != baseline.birthday ||
        _acquaintanceYear != baseline.acquaintanceYear;
  }

  Future<void> _requestClose() async {
    if (_saving) {
      return;
    }
    if (_hasUnsavedChanges) {
      final bool discard = await _confirm(
        context.l10n.peopleDiscardChangesTitle,
        context.l10n.peopleDiscardChangesBody,
        confirmLabel: context.l10n.peopleDiscardChangesAction,
      );
      if (!discard || !mounted) {
        return;
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    _commitAliasInput();
    final AppSessionState state = await ref.read(
      effectiveAppSessionProvider.future,
    );
    final session = state.session;
    if (!state.isUnlocked || session == null || !mounted) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showAppFeedbackToast(context, l10n.peopleNameRequired);
      return;
    }
    if (_acquaintanceYear != null &&
        !isValidAcquaintanceYear(_acquaintanceYear)) {
      showAppFeedbackToast(
        context,
        l10n.peopleSaveFailure(l10n.peopleFieldAcquaintanceYear),
      );
      return;
    }

    bool addOldNameAsAlias = false;
    if (_loaded != null &&
        normalizePersonName(_loaded!.name) != normalizePersonName(name)) {
      addOldNameAsAlias = await _confirm(
        l10n.peopleRenameKeepAliasTitle,
        l10n.peopleRenameKeepAliasBody,
        confirmLabel: l10n.peopleRenameKeepAliasAction,
      );
      if (!mounted) {
        return;
      }
    }

    final PersonDraft draft = PersonDraft(
      name: name,
      aliases: List<String>.from(_aliases),
      relationships: Set<PersonRelationship>.from(_relationships),
      relationshipDescription: _relationshipDescCtrl.text,
      notes: _notesCtrl.text,
      friendliness: _friendliness,
      accentArgb: _accentArgb,
      birthday: _birthday,
      acquaintanceYear: _acquaintanceYear,
    );

    setState(() => _saving = true);
    try {
      final service = ref.read(vaultPeopleServiceProvider);
      final Person saved = _loaded == null
          ? await service.createPerson(session, draft)
          : await service.updatePerson(
              session,
              _loaded!.id,
              draft,
              addOldNameAsAlias: addOldNameAsAlias,
            );
      ref.invalidate(peopleCatalogProvider);
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } on PersonNameValidationException catch (error) {
      if (error.requiresConfirmation) {
        if (!mounted) {
          return;
        }
        final bool confirmed = await _confirm(
          context.l10n.peopleWarningConfirmTitle,
          context.l10n.peopleWarningConfirmBody,
          confirmLabel: context.l10n.peopleSaveAction,
        );
        if (!confirmed || !mounted) {
          return;
        }
        try {
          final service = ref.read(vaultPeopleServiceProvider);
          final Person saved = _loaded == null
              ? await service.createPerson(
                  session,
                  draft,
                  confirmWarnings: true,
                )
              : await service.updatePerson(
                  session,
                  _loaded!.id,
                  draft,
                  confirmWarnings: true,
                  addOldNameAsAlias: addOldNameAsAlias,
                );
          ref.invalidate(peopleCatalogProvider);
          if (mounted) {
            Navigator.of(context).pop(saved);
          }
        } on Object catch (retryError) {
          if (mounted) {
            showAppFeedbackToast(
              context,
              context.l10n.peopleSaveFailure(
                userFacingErrorMessage(retryError, l10n: context.l10n),
              ),
            );
          }
        }
      } else if (error.hasConflict && mounted) {
        showAppFeedbackToast(context, context.l10n.peopleNameConflict);
      }
    } on Object catch (error) {
      if (mounted) {
        showAppFeedbackToast(
          context,
          context.l10n.peopleSaveFailure(
            userFacingErrorMessage(error, l10n: context.l10n),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  InputDecoration _fieldDecoration({
    required String labelText,
    String? hintText,
    Widget? suffixIcon,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: cs.surface.withValues(alpha: 0.95),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _aliasesEditor(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _aliasInputCtrl,
          enabled: !_saving,
          textInputAction: TextInputAction.done,
          decoration: _fieldDecoration(
            labelText: l10n.peopleAddAliasLabel,
            hintText: l10n.peopleFieldAliasesHint,
            suffixIcon: IconButton(
              tooltip: l10n.peopleAddAliasAction,
              onPressed: _saving || _aliasInputCtrl.text.trim().isEmpty
                  ? null
                  : _commitAliasInput,
              icon: const Icon(Icons.add_rounded),
            ),
          ).copyWith(errorText: _aliasInputError),
          onChanged: (String value) {
            if (_aliasInputError != null) {
              setState(() => _aliasInputError = null);
            } else {
              setState(() {});
            }
            final TextRange composing = _aliasInputCtrl.value.composing;
            if ((!composing.isValid || composing.isCollapsed) &&
                RegExp(r'[,，\n]').hasMatch(value)) {
              _commitAliasInput();
            }
          },
          onSubmitted: (_) => _commitAliasInput(),
        ),
        if (_aliases.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _aliases.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) => InputChip(
                label: Text(_aliases[index]),
                deleteButtonTooltipMessage: l10n.peopleRemoveAliasAction(
                  _aliases[index],
                ),
                onDeleted: _saving
                    ? null
                    : () => setState(() => _aliases.removeAt(index)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _relationshipsEditor(AppLocalizations l10n) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        key: const Key('person-relationships-list'),
        scrollDirection: Axis.horizontal,
        itemCount: PersonRelationship.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final PersonRelationship rel = PersonRelationship.values[index];
          return FilterChip(
            label: Text(
              personRelationshipLabel(l10n, rel),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            selected: _relationships.contains(rel),
            onSelected: _saving
                ? null
                : (bool value) {
                    setState(() {
                      if (value) {
                        _relationships.add(rel);
                      } else {
                        _relationships.remove(rel);
                      }
                    });
                  },
          );
        },
      ),
    );
  }

  Future<void> _pickCustomColor() async {
    final Color initialColor;
    if (_accentArgb != null) {
      initialColor = Color(_accentArgb!);
    } else if (_loaded != null) {
      initialColor = defaultPersonAccentColor(_loaded!.id);
    } else {
      initialColor = kAccentColorPresets.first;
    }
    final Color? picked = await showAccentColorWheelDialog(
      context,
      initialColor: initialColor,
      title: context.l10n.peopleChooseCustomColor,
      previewLabel: context.l10n.tagPreviewLabel,
      previewText: _nameCtrl.text.trim().isEmpty
          ? context.l10n.peopleEmptyTitle
          : _nameCtrl.text.trim(),
      copiedMessage: context.l10n.tagColorCodeCopiedMessage,
      cancelLabel: context.l10n.commonActionCancel,
      saveLabel: context.l10n.tagSaveButton,
    );
    if (picked != null && mounted) {
      setState(() => _accentArgb = colorArgb32(picked));
    }
  }

  Widget _colorEditor(AppLocalizations l10n, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              l10n.peopleFieldColor,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              _accentArgb == null
                  ? l10n.peopleColorAutomatic
                  : l10n.peopleColorCustom,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            key: const Key('person-color-list'),
            scrollDirection: Axis.horizontal,
            itemCount: kAccentColorPresets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              final int presetIndex = index;
              final Color color = kAccentColorPresets[presetIndex];
              final int argb = colorArgb32(color);
              final bool selected = _accentArgb == argb;
              final Color onAccent = accentOnSwatchColor(color);
              final String label = l10n.peopleColorPreset(presetIndex + 1);
              return Tooltip(
                message: label,
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: label,
                  child: InkResponse(
                    key: Key('person-color-preset-$presetIndex'),
                    onTap: _saving
                        ? null
                        : () => setState(() => _accentArgb = argb),
                    radius: 24,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentSwatchColor(color),
                        border: Border.all(
                          color: selected
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.18),
                          width: selected ? 3 : 1.5,
                        ),
                      ),
                      child: selected
                          ? Icon(Icons.check_rounded, color: onAccent)
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ChoiceChip(
              key: const Key('person-color-automatic'),
              avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(l10n.peopleColorAutomatic),
              selected: _accentArgb == null,
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _accentArgb = null),
            ),
            OutlinedButton.icon(
              key: const Key('person-color-custom'),
              onPressed: _saving ? null : () => unawaited(_pickCustomColor()),
              icon: const Icon(Icons.palette_outlined, size: 18),
              label: Text(l10n.peopleChooseCustomColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _friendlinessSlider(AppLocalizations l10n, ColorScheme cs) {
    final ThemeData theme = Theme.of(context);
    final int value = _friendliness.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              l10n.peopleFieldFriendliness,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              personFriendlinessLabel(l10n, value),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          min: FriendlinessLevel.min.toDouble(),
          max: FriendlinessLevel.max.toDouble(),
          divisions: FriendlinessLevel.max - FriendlinessLevel.min,
          value: value.toDouble(),
          label: personFriendlinessLabel(l10n, value),
          semanticFormatterCallback: (double next) {
            final int level = next.round();
            return l10n.peopleFriendlinessValueSemantics(
              personFriendlinessLabel(l10n, level),
              level,
              FriendlinessLevel.max,
            );
          },
          onChanged: _saving
              ? null
              : (double next) => setState(
                  () => _friendliness = FriendlinessLevel(next.round()),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: <Widget>[
              Text(
                l10n.peopleFriendlinessLow,
                style: theme.textTheme.labelSmall,
              ),
              const Spacer(),
              Text(
                l10n.peopleFriendlinessHigh,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _expandingTextFieldDecoration(String label) {
    return _fieldDecoration(
      labelText: label,
    ).copyWith(alignLabelWithHint: true);
  }

  Widget _dateField({
    required String label,
    required String valueText,
    required bool hasValue,
    required String clearTooltip,
    required VoidCallback onPick,
    required VoidCallback? onClear,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return InkWell(
      onTap: _saving ? null : onPick,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        isEmpty: !hasValue,
        decoration: _fieldDecoration(
          labelText: label,
          suffixIcon: hasValue && onClear != null
              ? IconButton(
                  tooltip: clearTooltip,
                  onPressed: _saving ? null : onClear,
                  icon: const Icon(Icons.clear_rounded, size: 20),
                )
              : Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
        ),
        child: Text(
          hasValue ? valueText : ' ',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: hasValue ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _formSection({required String title, required List<Widget> children}) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }

  Widget _sectionDivider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Divider(height: 1),
  );

  Widget _formBody(
    AppLocalizations l10n,
    ColorScheme cs, {
    required String birthdayText,
    required String acquaintanceText,
  }) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverList.list(
            children: <Widget>[
              _formSection(
                title: l10n.peopleSectionBasic,
                children: <Widget>[
                  TextField(
                    controller: _nameCtrl,
                    enabled: !_saving,
                    autofocus: !widget.isEditing && widget.initialName.isEmpty,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDecoration(
                      labelText: l10n.peopleFieldName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _aliasesEditor(l10n),
                ],
              ),
              _sectionDivider(),
              _formSection(
                title: l10n.peopleSectionRelationship,
                children: <Widget>[
                  _relationshipsEditor(l10n),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _relationshipDescCtrl,
                    enabled: !_saving,
                    minLines: 1,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: _expandingTextFieldDecoration(
                      l10n.peopleFieldRelationshipDescription,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _friendlinessSlider(l10n, cs),
                ],
              ),
              _sectionDivider(),
              _formSection(
                title: l10n.peopleSectionOther,
                children: <Widget>[
                  _dateField(
                    label: l10n.peopleFieldAcquaintanceYear,
                    valueText: acquaintanceText,
                    hasValue: _acquaintanceYear != null,
                    clearTooltip: l10n.peopleClearAcquaintanceYear,
                    onPick: () => unawaited(_pickAcquaintanceYear()),
                    onClear: () => setState(() => _acquaintanceYear = null),
                  ),
                  const SizedBox(height: 12),
                  _dateField(
                    label: l10n.peopleFieldBirthday,
                    valueText: birthdayText,
                    hasValue: _birthday != null,
                    clearTooltip: l10n.peopleClearBirthday,
                    onPick: () => unawaited(_pickBirthday()),
                    onClear: () => setState(() => _birthday = null),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    enabled: !_saving,
                    minLines: 1,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: _expandingTextFieldDecoration(
                      l10n.peopleFieldNotes,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _colorEditor(l10n, cs),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footer(AppLocalizations l10n, ColorScheme cs) {
    return Material(
      color: cs.surface,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: <Widget>[
            TextButton(
              onPressed: _saving ? null : () => unawaited(_requestClose()),
              child: Text(l10n.commonActionCancel),
            ),
            const Spacer(),
            AppActionButton(
              label: l10n.peopleSaveAction,
              icon: Icons.check_rounded,
              appearance: AppActionButtonAppearance.primary,
              loading: _saving,
              onPressed: _saving ? null : () => unawaited(_save()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing && !_hydrated) {
      final AsyncValue<Person?> personAsync = ref.watch(
        personDetailProvider(widget.personId!),
      );
      if (personAsync.isLoading) {
        return AccentDialogShell(
          icon: Icons.person_rounded,
          title: context.l10n.peopleEditTitle,
          onClose: () => unawaited(_requestClose()),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      final Person? person = personAsync.asData?.value;
      if (person == null) {
        if (!_editMissingHandled) {
          _editMissingHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
        return AccentDialogShell(
          icon: Icons.person_rounded,
          title: context.l10n.peopleEditTitle,
          onClose: () => unawaited(_requestClose()),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(context.l10n.peopleEmptyTitle),
          ),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hydrated) {
          setState(() => _hydrate(person));
        }
      });
      return AccentDialogShell(
        icon: Icons.person_rounded,
        title: context.l10n.peopleEditTitle,
        onClose: () => unawaited(_requestClose()),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String birthdayText = _birthday == null
        ? ''
        : DisplayFormat.formatBirthday(
            l10n,
            month: _birthday!.month,
            day: _birthday!.day,
          );
    final String acquaintanceText = _acquaintanceYear == null
        ? ''
        : DisplayFormat.formatYear(l10n, _acquaintanceYear!);

    final String title = widget.isEditing
        ? l10n.peopleEditTitle
        : l10n.peopleCreateTitle;
    final Widget body = _formBody(
      l10n,
      cs,
      birthdayText: birthdayText,
      acquaintanceText: acquaintanceText,
    );
    final Widget shell = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom;
        final double bodyHeight = (availableHeight - 166).clamp(80.0, 680.0);
        return AccentDialogShell(
          icon: Icons.person_rounded,
          title: title,
          closeEnabled: !_saving,
          onClose: () => unawaited(_requestClose()),
          footer: _footer(l10n, cs),
          child: SizedBox(height: bodyHeight, child: body),
        );
      },
    );
    return PopScope(
      canPop: !_hasUnsavedChanges && !_saving,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_requestClose());
        }
      },
      child: shell,
    );
  }
}
