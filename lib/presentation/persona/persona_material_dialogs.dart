import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/persona/persona_speaker_role_dropdown.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';
import 'package:quill_diary/shared/presentation/private_text_controller.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

class PersonaMaskDialog extends ConsumerStatefulWidget {
  const PersonaMaskDialog({
    super.key,
    required this.title,
    required this.text,
    required this.ranges,
    required this.onChanged,
    this.references = const [],
  });

  final String title;
  final String text;
  final List<PrivateTextRange> ranges;
  final void Function(List<PrivateTextRange>) onChanged;
  final List<PrivateTextRange> references;

  @override
  ConsumerState<PersonaMaskDialog> createState() => _PersonaMaskDialogState();
}

class _PersonaMaskDialogState extends ConsumerState<PersonaMaskDialog> {
  final controller = PrivateTextController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    controller.setDocument(widget.text, widget.ranges);
  }

  @override
  void dispose() {
    controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialogShell(
      title: widget.title,
      leading: ListenableBuilder(
        listenable: controller,
        builder: (_, _) => IconButton(
          tooltip: controller.selectionIsPrivate
              ? l10n.aiUnhideSelection
              : l10n.aiHideSelection,
          onPressed: controller.selection.isCollapsed
              ? null
              : () {
                  var range = personaSelectionRange(
                    controller.text,
                    controller.selection.start,
                    controller.selection.end,
                  );
                  for (final reference in widget.references) {
                    if (range.start < reference.end &&
                        range.end > reference.start) {
                      range = PrivateTextRange(
                        range.start < reference.start
                            ? range.start
                            : reference.start,
                        range.end > reference.end ? range.end : reference.end,
                      );
                    }
                  }
                  controller.selection = TextSelection(
                    baseOffset: range.start,
                    extentOffset: range.end,
                  );
                  if (controller.selectionIsPrivate) {
                    controller.unhideSelection();
                  } else {
                    controller.hideSelection();
                  }
                  widget.onChanged(controller.privateRanges);
                },
          icon: Icon(
            controller.selectionIsPrivate
                ? Icons.visibility
                : Icons.visibility_off,
          ),
        ),
      ),
      content: PersonaDialogBody(
        child: AppScrollbar(
          controller: _scroll,
          reserveGutter: true,
          track: AppScrollbarTrack.frame,
          child: TextField(
            controller: controller,
            scrollController: _scroll,
            style: watchPersonalizationPreferences(ref).typography
                .bodyTextStyle(Theme.of(context).textTheme),
            readOnly: true,
            expands: true,
            minLines: null,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonActionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.personaChecked),
        ),
      ],
    );
  }
}

class PersonaChatDateEditorMessage {
  const PersonaChatDateEditorMessage({
    required this.messageId,
    required this.speaker,
    required this.sentAtLocal,
    required this.text,
  });

  final String messageId;
  final String speaker;
  final String sentAtLocal;
  final String text;
}

class PersonaChatDateEditResult {
  const PersonaChatDateEditResult({
    required this.messageId,
    required this.text,
    required this.ranges,
  });

  final String messageId;
  final String text;
  final List<PrivateTextRange> ranges;
}

class PersonaChatDateEditorDialog extends StatefulWidget {
  const PersonaChatDateEditorDialog({
    super.key,
    required this.title,
    required this.messages,
    required this.ranges,
  });

  final String title;
  final List<PersonaChatDateEditorMessage> messages;
  final Map<String, List<PrivateTextRange>> ranges;

  @override
  State<PersonaChatDateEditorDialog> createState() =>
      _PersonaChatDateEditorDialogState();
}

class _PersonaChatDateEditorDialogState
    extends State<PersonaChatDateEditorDialog> {
  final _controllers = <String, PrivateTextController>{};
  final _scroll = ScrollController();
  final _deletedMessageIds = <String>{};
  String? _activeMessageId;

  @override
  void initState() {
    super.initState();
    for (final message in widget.messages) {
      final controller = PrivateTextController()
        ..setDocument(message.text, widget.ranges[message.messageId] ?? []);
      controller.addListener(() => _selectionChanged(message.messageId));
      _controllers[message.messageId] = controller;
    }
  }

  void _selectionChanged(String messageId) {
    if (_deletedMessageIds.contains(messageId)) return;
    final selection = _controllers[messageId]!.selection;
    if (selection.isValid && mounted) {
      setState(() => _activeMessageId = messageId);
    }
  }

  void _toggleSelectionPrivacy() {
    final messageId = _activeMessageId;
    final controller = messageId == null ? null : _controllers[messageId];
    if (controller == null || controller.selection.isCollapsed) return;
    final selection = controller.selection;
    final range = personaSelectionRange(
      controller.text,
      selection.start,
      selection.end,
    );
    controller.selection = TextSelection(
      baseOffset: range.start,
      extentOffset: range.end,
    );
    if (controller.selectionIsPrivate) {
      controller.unhideSelection();
    } else {
      controller.hideSelection();
    }
  }

  void _deleteMessage(String messageId) {
    if (_activeMessageId == messageId) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() {
      _deletedMessageIds.add(messageId);
      if (_activeMessageId == messageId) _activeMessageId = null;
    });
  }

  void _apply() {
    Navigator.pop(context, [
      for (final message in widget.messages)
        if (!_deletedMessageIds.contains(message.messageId) &&
            _controllers[message.messageId]!.text.trim().isNotEmpty)
          PersonaChatDateEditResult(
            messageId: message.messageId,
            text: _controllers[message.messageId]!.text,
            ranges: _controllers[message.messageId]!.privateRanges,
          ),
    ]);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages
        .where((message) => !_deletedMessageIds.contains(message.messageId))
        .toList();
    final active = _activeMessageId == null
        ? null
        : _controllers[_activeMessageId!];
    final canToggle =
        active != null &&
        active.selection.isValid &&
        !active.selection.isCollapsed;
    final l10n = context.l10n;
    return AppDialogShell(
      title: widget.title,
      leading: IconButton(
        tooltip: active?.selectionIsPrivate == true
            ? l10n.aiUnhideSelection
            : l10n.aiHideSelection,
        onPressed: canToggle ? _toggleSelectionPrivacy : null,
        icon: Icon(
          active?.selectionIsPrivate == true
              ? Icons.visibility
              : Icons.visibility_off,
        ),
      ),
      content: PersonaDialogBody(
        child: messages.isEmpty
            ? Text(l10n.personaNoChatMessages)
            : AppScrollbar(
                controller: _scroll,
                reserveGutter: true,
                child: ListView.separated(
                  controller: _scroll,
                  padding: EdgeInsets.zero,
                  itemCount: messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _PersonaChatDateMessageEditor(
                      key: ValueKey(message.messageId),
                      message: message,
                      controller: _controllers[message.messageId]!,
                      onDelete: () => _deleteMessage(message.messageId),
                    );
                  },
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonActionCancel),
        ),
        FilledButton(onPressed: _apply, child: Text(l10n.commonActionApply)),
      ],
    );
  }
}

class _PersonaChatDateMessageEditor extends StatelessWidget {
  const _PersonaChatDateMessageEditor({
    required this.message,
    required this.controller,
    required this.onDelete,
    super.key,
  });

  final PersonaChatDateEditorMessage message;
  final TextEditingController controller;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: message.speaker,
                      style: TextStyle(color: colors.primary),
                    ),
                    TextSpan(text: ' · ${_messageTime(message.sentAtLocal)}'),
                  ],
                ),
                style: textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: context.l10n.commonActionDelete,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: colors.onSurfaceVariant,
              iconSize: 18,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        TextField(
          controller: controller,
          style: textTheme.bodyLarge?.copyWith(height: 1.4),
          minLines: 1,
          maxLines: null,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            filled: false,
            isCollapsed: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
          ),
        ),
      ],
    );
  }
}

class PersonaPasteDialog extends StatefulWidget {
  const PersonaPasteDialog({super.key});

  @override
  State<PersonaPasteDialog> createState() => _PersonaPasteDialogState();
}

class _PersonaPasteDialogState extends State<PersonaPasteDialog> {
  final text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AppDialogShell(
      title: l10n.personaPaste,
      content: PersonaDialogBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.personaPrivacyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AppScrollbar(
                controller: _scroll,
                reserveGutter: true,
                track: AppScrollbarTrack.frame,
                child: TextField(
                  controller: text,
                  scrollController: _scroll,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonActionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, text.text),
          child: Text(l10n.commonActionConfirm),
        ),
      ],
    );
  }
}

class PersonaRolesDialog extends StatefulWidget {
  const PersonaRolesDialog({super.key, required this.chat});

  final PersonaChatImport chat;

  @override
  State<PersonaRolesDialog> createState() => _PersonaRolesDialogState();
}

class _PersonaRolesDialogState extends State<PersonaRolesDialog> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // 內建格式已有說話者名單，這裡只要求至少一位目標對象。
    final canConfirm = widget.chat.speakers.any(
      (speaker) => speaker.role == PersonaSpeakerRole.personaSubject,
    );
    return AppDialogShell(
      title: l.personaRoles,
      content: PersonaDialogBody(
        child: AppScrollbar(
          controller: _scroll,
          reserveGutter: true,
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.zero,
            children: [
              for (final speaker in widget.chat.speakers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PersonaSpeakerRoleCard(
                    label: speaker.label,
                    role: speaker.role,
                    onChanged: (role) => setState(() => speaker.role = role),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonActionCancel),
        ),
        FilledButton(
          onPressed: canConfirm ? () => Navigator.pop(context, true) : null,
          child: Text(l.commonActionConfirm),
        ),
      ],
    );
  }
}

class _ExportFileType extends StatelessWidget {
  const _ExportFileType(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.9),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _ExportStep extends StatelessWidget {
  const _ExportStep({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double badge = MediaQuery.textScalerOf(context).scale(22);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: badge,
            height: badge,
            child: Center(
              child: Text(
                '$index',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExportStepGroup {
  const _ExportStepGroup({this.label, required this.steps});

  final String? label;
  final List<String> steps;
}

class _ExportPlatformCard extends StatelessWidget {
  const _ExportPlatformCard({
    required this.title,
    required this.groups,
    this.notes = const [],
  });

  final String title;
  final List<_ExportStepGroup> groups;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppInsetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final group in groups) ...[
            if (group.label != null) ...[
              const SizedBox(height: 10),
              Text(
                group.label!,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            for (final (index, step) in group.steps.indexed) ...[
              const SizedBox(height: 8),
              _ExportStep(index: index + 1, text: step),
            ],
          ],
          for (final note in notes) ...[
            const SizedBox(height: 10),
            AppFeedbackBanner(message: note, tone: AppFeedbackTone.warning),
          ],
        ],
      ),
    );
  }
}

class PersonaChatExportHelpDialog extends StatelessWidget {
  const PersonaChatExportHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.45,
    );
    return AppDialogShell(
      title: l10n.personaChatExportHelp,
      icon: const Icon(Icons.info_outline_rounded),
      content: PersonaDialogBody(
        child: AppScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInsetPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ExportFileType('.txt'),
                        _ExportFileType('.json'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(l10n.personaChatExportHelpIntro, style: muted),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ExportPlatformCard(
                title: l10n.personaChatExportLineTitle,
                groups: [
                  _ExportStepGroup(
                    label: l10n.personaChatExportOnPhone,
                    steps: [
                      l10n.personaChatExportLinePhoneStep1,
                      l10n.personaChatExportLinePhoneStep2,
                      l10n.personaChatExportLinePhoneStep3,
                    ],
                  ),
                  _ExportStepGroup(
                    label: l10n.personaChatExportOnDesktop,
                    steps: [
                      l10n.personaChatExportLineDesktopStep1,
                      l10n.personaChatExportLineDesktopStep2,
                    ],
                  ),
                ],
                notes: [l10n.personaChatExportLineNote],
              ),
              const SizedBox(height: 12),
              _ExportPlatformCard(
                title: l10n.personaChatExportMessengerTitle,
                groups: [
                  _ExportStepGroup(
                    steps: [
                      l10n.personaChatExportMessengerStep1,
                      l10n.personaChatExportMessengerStep2,
                      l10n.personaChatExportMessengerStep3,
                    ],
                  ),
                ],
                notes: [l10n.personaChatExportMessengerNote],
              ),
              const SizedBox(height: 12),
              _ExportPlatformCard(
                title: l10n.personaChatExportMessengerSecureTitle,
                groups: [
                  _ExportStepGroup(
                    steps: [
                      l10n.personaChatExportMessengerSecureStep1,
                      l10n.personaChatExportMessengerSecureStep2,
                      l10n.personaChatExportMessengerSecureStep3,
                    ],
                  ),
                ],
                notes: [
                  l10n.personaChatExportMessengerSecureNoteComputer,
                  l10n.personaChatExportMessengerSecureNotePath,
                  l10n.personaChatExportMessengerSecureNoteIncomplete,
                ],
              ),
              const SizedBox(height: 12),
              _ExportPlatformCard(
                title: l10n.personaChatExportInstagramTitle,
                groups: [
                  _ExportStepGroup(
                    steps: [
                      l10n.personaChatExportInstagramStep1,
                      l10n.personaChatExportInstagramStep2,
                      l10n.personaChatExportInstagramStep3,
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l10n.personaChatExportTrademarkNote, style: muted),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonActionClose),
        ),
      ],
    );
  }
}

class PersonaDiaryPreviewDialog extends StatelessWidget {
  const PersonaDiaryPreviewDialog({
    super.key,
    required this.title,
    required this.body,
    required this.bodyStyle,
  });

  final String title;
  final String body;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      title: title,
      content: PersonaDialogBody(
        child: AppScrollView(child: SelectableText(body, style: bodyStyle)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonActionClose),
        ),
      ],
    );
  }
}

class PersonaChatMaterialPage extends StatefulWidget {
  const PersonaChatMaterialPage({
    super.key,
    required this.source,
    required this.readChat,
    required this.bodyStyle,
    required this.onEditRoles,
    required this.onClearDate,
    required this.onPickDate,
    required this.onToggleDate,
    required this.onEditDate,
  });

  final PersonaChatSource source;
  final PersonaChatImport Function() readChat;
  final TextStyle bodyStyle;
  final Future<void> Function() onEditRoles;
  final void Function(bool start) onClearDate;
  final Future<void> Function(bool start) onPickDate;
  final void Function(List<PersonaImportMessage> messages, bool included)
  onToggleDate;
  final Future<void> Function(String date, List<PersonaImportMessage> messages)
  onEditDate;

  @override
  State<PersonaChatMaterialPage> createState() =>
      _PersonaChatMaterialPageState();
}

class _PersonaChatMaterialPageState extends State<PersonaChatMaterialPage> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final source = widget.source;
    final chat = widget.readChat();
    final messages = chat.messagesInWindow(source).toList();
    return AppDialogShell(
      title: l.personaChats,
      content: PersonaDialogBody(
        child: AppScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _materialHeader(l, source, chat, messages),
              const SizedBox(height: 12),
              if (messages.isEmpty) Text(l.personaNoChatMessages),
              ..._dateSections(source, chat, messages),
            ],
          ),
        ),
      ),
    );
  }

  Widget _materialHeader(
    AppLocalizations l,
    PersonaChatSource source,
    PersonaChatImport chat,
    List<PersonaImportMessage> messages,
  ) {
    final includedCount = messages
        .where((message) => !source.excluded.contains(message.id))
        .length;
    final canPickDate = chat.messages.isNotEmpty;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.12),
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.forum_outlined, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.personaIncludedCount(includedCount),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await widget.onEditRoles();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.people_outline, size: 18),
                label: Text(l.personaRoles),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dateFilter(
                  label: l.personaFromDate,
                  value: source.fromDate,
                  emptyLabel: l.personaAllDates,
                  enabled: canPickDate,
                  start: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dateFilter(
                  label: l.personaToDate,
                  value: source.toDate,
                  emptyLabel: l.personaAllDates,
                  enabled: canPickDate,
                  start: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateFilter({
    required String label,
    required String? value,
    required String emptyLabel,
    required bool enabled,
    required bool start,
  }) {
    return _DateFilterCard(
      label: label,
      value: value ?? emptyLabel,
      clearable: value != null,
      onClear: () {
        widget.onClearDate(start);
        setState(() {});
      },
      onTap: enabled
          ? () async {
              await widget.onPickDate(start);
              if (mounted) setState(() {});
            }
          : null,
    );
  }

  List<Widget> _dateSections(
    PersonaChatSource source,
    PersonaChatImport chat,
    List<PersonaImportMessage> messages,
  ) {
    final speakers = {for (final speaker in chat.speakers) speaker.id: speaker};
    final groups = <_ChatDateGroup>[];
    for (final message in messages) {
      final date = message.sentAtLocal.substring(0, 10);
      if (groups.isEmpty || groups.last.date != date) {
        groups.add(_ChatDateGroup(date));
      }
      groups.last.messages.add(message);
    }
    return [
      for (final group in groups)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _ChatDateGroupSection(
            group: group,
            speakers: speakers,
            source: source,
            bodyStyle: widget.bodyStyle,
            onIncludedChanged: (messages, included) {
              widget.onToggleDate(messages, included);
              setState(() {});
            },
            onEdit: (date, messages) async {
              await widget.onEditDate(date, messages);
              if (mounted) setState(() {});
            },
          ),
        ),
    ];
  }
}

class _ChatDateGroup {
  _ChatDateGroup(this.date);

  final String date;
  final List<PersonaImportMessage> messages = [];
}

class _ChatDateGroupSection extends StatelessWidget {
  const _ChatDateGroupSection({
    required this.group,
    required this.speakers,
    required this.source,
    required this.bodyStyle,
    required this.onIncludedChanged,
    required this.onEdit,
  });

  final _ChatDateGroup group;
  final Map<String, PersonaImportSpeaker> speakers;
  final PersonaChatSource source;
  final TextStyle bodyStyle;
  final void Function(List<PersonaImportMessage> messages, bool included)
  onIncludedChanged;
  final Future<void> Function(String date, List<PersonaImportMessage> messages)
  onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final includedCount = group.messages
        .where((message) => !source.excluded.contains(message.id))
        .length;
    final allIncluded = includedCount == group.messages.length;
    final noneIncluded = includedCount == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
          child: Row(
            children: [
              Checkbox(
                value: allIncluded
                    ? true
                    : noneIncluded
                    ? false
                    : null,
                tristate: true,
                onChanged: (value) =>
                    onIncludedChanged(group.messages, value == true),
              ),
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  group.date,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              TextButton(
                onPressed: () => unawaited(onEdit(group.date, group.messages)),
                child: Text(context.l10n.personaEdit),
              ),
            ],
          ),
        ),
        for (final message in group.messages)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChatMessageCard(
              message: message,
              speaker: speakers[message.speakerId]!,
              included: !source.excluded.contains(message.id),
              hiddenRanges: source.hidden[message.id] ?? const [],
              bodyStyle: bodyStyle,
            ),
          ),
      ],
    );
  }
}

class _DateFilterCard extends StatelessWidget {
  const _DateFilterCard({
    required this.label,
    required this.value,
    required this.clearable,
    required this.onClear,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool clearable;
  final VoidCallback onClear;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (clearable)
                IconButton(
                  tooltip: context.l10n.personaClearDate,
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessageCard extends StatelessWidget {
  const _ChatMessageCard({
    required this.message,
    required this.speaker,
    required this.included,
    required this.hiddenRanges,
    required this.bodyStyle,
  });

  final PersonaImportMessage message;
  final PersonaImportSpeaker speaker;
  final bool included;
  final List<PrivateTextRange> hiddenRanges;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: included
          ? colors.surfaceContainerLow
          : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  speaker.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: included ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _messageTime(message.sentAtLocal),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                const Spacer(),
                if (hiddenRanges.isNotEmpty) ...[
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  context.l10n.personaHiddenCount(hiddenRanges.length),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 4),
            PrivateText(
              text: message.text,
              ranges: hiddenRanges,
              style: bodyStyle.copyWith(
                color: included ? colors.onSurface : colors.onSurfaceVariant,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

String _messageTime(String sentAtLocal) =>
    sentAtLocal.length >= 16 ? sentAtLocal.substring(11, 16) : sentAtLocal;
