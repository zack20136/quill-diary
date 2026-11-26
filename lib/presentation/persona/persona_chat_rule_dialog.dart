import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/persona/persona_controller.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/persona/persona_privacy.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/persona/persona_speaker_role_dropdown.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/private_text_controller.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_section.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text_field.dart';

/// 內建格式失敗後，整份原文匯入。取消回傳 null。
class PersonaChatRuleDialog extends StatefulWidget {
  const PersonaChatRuleDialog({
    super.key,
    required this.input,
    required this.vaultId,
    required this.personId,
    required this.personaId,
    this.existing,
    this.people = const [],
    this.hidePersonNames = true,
  });

  final String input;
  final String vaultId;
  final String personId;
  final String personaId;
  final PersonaChatImport? existing;
  final List<Person> people;
  final bool hidePersonNames;

  @override
  State<PersonaChatRuleDialog> createState() => _PersonaChatRuleDialogState();
}

class _NamedSpeaker {
  _NamedSpeaker(this.label, {this.id, this.role = PersonaSpeakerRole.unknown});

  final String label;
  final String? id;
  PersonaSpeakerRole role;
}

class _PersonaChatRuleDialogState extends State<PersonaChatRuleDialog> {
  late final List<_NamedSpeaker> _names = [
    for (final speaker in widget.existing?.speakers ?? const [])
      _NamedSpeaker(speaker.label, id: speaker.id, role: speaker.role),
  ];
  final _addedName = TextEditingController();
  final _scroll = ScrollController();
  late final _text = PrivateTextController(detectRanges: _detectRanges);

  @override
  void initState() {
    super.initState();
    _text.setDocument(
      widget.input,
      widget.existing?.rawHidden ?? const [],
      widget.existing?.rawRevealed ?? const [],
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _addedName.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _canImport =>
      personaSourceHasVisibleText(widget.input, _text.privateRanges);

  void _addName() {
    final label = _addedName.text.trim();
    if (label.isEmpty || _names.any((name) => name.label == label)) return;
    setState(() {
      _names.add(_NamedSpeaker(label));
      _addedName.clear();
    });
    _text.refreshHighlights();
  }

  List<PersonaImportSpeaker> _speakers() {
    final used = {
      for (final name in _names)
        if (name.id != null) name.id!,
    };
    var next = 1;
    String freshId() {
      while (!used.add('named-s$next')) {
        next++;
      }
      return 'named-s$next';
    }

    return [
      for (final name in _names)
        PersonaImportSpeaker(
          id: name.id ?? freshId(),
          label: name.label,
          role: name.role,
        ),
    ];
  }

  List<PrivateTextRange> _detectRanges(
    String text,
    List<PrivateTextRange> manual,
    List<PrivateTextRange> revealed,
  ) {
    final chat = _buildImport(text, manual);
    final privacy = PersonaTokenRegistry(
      widget.people,
      hideNames: widget.hidePersonNames,
    )..registerImport(chat);
    return privacy
        .protectForDisplay(
          text,
          scope: chat.importId,
          ranges: manual,
          revealedRanges: revealed,
          maskImportNames: true,
        )
        .highlightRanges;
  }

  PersonaChatImport _buildImport(String text, List<PrivateTextRange> hidden) =>
      PersonaChatImport.raw(
        vaultId: widget.vaultId,
        personId: widget.personId,
        personaId: widget.personaId,
        importId: widget.existing?.importId,
        importedAt: widget.existing?.importedAt,
        text: text,
        speakers: _speakers(),
        hidden: hidden,
        revealed: _text.revealedRanges,
      );

  void _import() {
    Navigator.pop(context, _buildImport(widget.input, _text.privateRanges));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final editing = widget.existing != null;
    return AppDialogShell(
      fillHeight: true,
      title: l.personaChatRuleTitle,
      icon: const Icon(Icons.notes_rounded),
      leading: ListenableBuilder(
        listenable: _text,
        builder: (_, _) => IconButton(
          tooltip: _text.selectionIsHidden
              ? l.aiUnhideSelection
              : l.aiHideSelection,
          onPressed: _text.selection.isCollapsed
              ? null
              : () {
                  if (_text.selectionIsHidden) {
                    _text.unhideSelection();
                  } else {
                    _text.hideSelection();
                  }
                  setState(() {});
                },
          icon: Icon(
            _text.selectionIsHidden ? Icons.visibility : Icons.visibility_off,
          ),
        ),
      ),
      content: AppScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            if (!_canImport)
              AppFeedbackBanner(
                message: l.personaChatRuleEmpty,
                tone: AppFeedbackTone.warning,
              ),
            AppDialogSummary(
              icon: Icons.info_outline_rounded,
              title: l.personaChatRuleIntroTitle,
              details: [l.personaChatRuleIntro],
            ),
            AppDialogSection(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Text(
                    l.personaChatRuleNames,
                    style: theme.textTheme.titleSmall,
                  ),
                  TextField(
                    controller: _addedName,
                    decoration: InputDecoration(
                      labelText: l.personaChatRuleNameHint,
                      suffixIcon: IconButton(
                        tooltip: l.personaChatRuleAddName,
                        onPressed: _addName,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ),
                    onSubmitted: (_) => _addName(),
                  ),
                ],
              ),
            ),
            for (final name in _names)
              PersonaSpeakerRoleCard(
                label: name.label,
                role: name.role,
                onChanged: (role) => setState(() => name.role = role),
              ),
            AppDialogSection(
              padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      l.personaChatRulePreview,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  AppScrollbar(
                    controller: _scroll,
                    track: AppScrollbarTrack.frame,
                    placement: AppScrollbarPlacement.gutter,
                    gutterWidth: 12,
                    child: PrivateTextField(
                      controller: _text,
                      scrollController: _scroll,
                      readOnly: true,
                      minLines: 3,
                      maxLines: 10,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonActionCancel),
        ),
        FilledButton(
          onPressed: _canImport ? _import : null,
          child: Text(editing ? l.commonActionApply : l.personaChatRuleImport),
        ),
      ],
    );
  }
}
