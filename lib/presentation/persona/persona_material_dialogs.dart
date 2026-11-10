import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';
import 'package:quill_diary/shared/presentation/private_text_controller.dart';
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

  @override
  void initState() {
    super.initState();
    controller.setDocument(widget.text, widget.ranges);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      leading: CloseButton(onPressed: () => Navigator.pop(context)),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: controller,
                style: watchPersonalizationPreferences(ref).typography
                    .bodyTextStyle(Theme.of(context).textTheme),
                readOnly: true,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ListenableBuilder(
                  listenable: controller,
                  builder: (_, _) => IconButton(
                    tooltip: controller.selectionIsPrivate
                        ? context.l10n.aiUnhideSelection
                        : context.l10n.aiHideSelection,
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
                                  range.end > reference.end
                                      ? range.end
                                      : reference.end,
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
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.l10n.personaChecked),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
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

  void _toggleSelection() {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: CloseButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? Center(child: Text(context.l10n.personaNoChatMessages))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return AppCard(
                          key: ValueKey(message.messageId),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          child: Column(
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
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                ' · ${_messageTime(message.sentAtLocal)}',
                                          ),
                                        ],
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: context.l10n.commonActionDelete,
                                    color: Theme.of(context).colorScheme.error,
                                    iconSize: 20,
                                    onPressed: () =>
                                        _deleteMessage(message.messageId),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _controllers[message.messageId]!,
                                minLines: 1,
                                maxLines: null,
                                textAlignVertical: TextAlignVertical.top,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    tooltip: active?.selectionIsPrivate == true
                        ? context.l10n.aiUnhideSelection
                        : context.l10n.aiHideSelection,
                    onPressed: canToggle ? _toggleSelection : null,
                    icon: Icon(
                      active?.selectionIsPrivate == true
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.commonActionCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _apply,
                    child: Text(context.l10n.commonActionApply),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.personaPaste),
      leading: CloseButton(onPressed: () => Navigator.pop(context)),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.personaPrivacyHint),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: text,
                maxLines: null,
                minLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, text.text),
              child: Text(context.l10n.commonActionConfirm),
            ),
          ),
        ],
      ),
    ),
  );
}

class PersonaRolesDialog extends StatefulWidget {
  const PersonaRolesDialog({super.key, required this.chat});

  final PersonaChatImport chat;

  @override
  State<PersonaRolesDialog> createState() => _PersonaRolesDialogState();
}

class _PersonaRolesDialogState extends State<PersonaRolesDialog> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canConfirm = widget.chat.speakers.any(
      (speaker) => speaker.role == PersonaSpeakerRole.personaSubject,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.personaRoles),
        leading: CloseButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  AppInsetPanel(
                    child: Text(
                      l.personaRolesHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final speaker in widget.chat.speakers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SpeakerRoleCard(
                        speaker: speaker,
                        onChanged: (role) =>
                            setState(() => speaker.role = role),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canConfirm
                      ? () => Navigator.pop(context, true)
                      : null,
                  icon: const Icon(Icons.check),
                  label: Text(l.commonActionConfirm),
                ),
              ),
            ),
          ],
        ),
      ),
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
    final speakers = {for (final speaker in chat.speakers) speaker.id: speaker};
    final messages = chat.messagesInWindow(source).toList();
    final includedCount = messages
        .where((message) => !source.excluded.contains(message.id))
        .length;
    final dateGroups = <_ChatDateGroup>[];
    for (final message in messages) {
      final date = message.sentAtLocal.substring(0, 10);
      if (dateGroups.isEmpty || dateGroups.last.date != date) {
        dateGroups.add(_ChatDateGroup(date));
      }
      dateGroups.last.messages.add(message);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.personaChats),
        leading: CloseButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .primary,
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
                            child: _DateFilterCard(
                              label: l.personaFromDate,
                              value: source.fromDate ?? l.personaAllDates,
                              clearable: source.fromDate != null,
                              onClear: () {
                                widget.onClearDate(true);
                                setState(() {});
                              },
                              onTap: chat.messages.isEmpty
                                  ? null
                                  : () async {
                                      await widget.onPickDate(true);
                                      if (mounted) setState(() {});
                                    },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DateFilterCard(
                              label: l.personaToDate,
                              value: source.toDate ?? l.personaAllDates,
                              clearable: source.toDate != null,
                              onClear: () {
                                widget.onClearDate(false);
                                setState(() {});
                              },
                              onTap: chat.messages.isEmpty
                                  ? null
                                  : () async {
                                      await widget.onPickDate(false);
                                      if (mounted) setState(() {});
                                    },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (messages.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.personaNoChatMessages),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.builder(
                itemCount: dateGroups.length,
                itemBuilder: (_, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ChatDateGroupSection(
                      group: dateGroups[index],
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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

class _SpeakerRoleCard extends StatelessWidget {
  const _SpeakerRoleCard({required this.speaker, required this.onChanged});

  final PersonaImportSpeaker speaker;
  final ValueChanged<PersonaSpeakerRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final role = speaker.role;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.secondary.withValues(alpha: 0.14),
                foregroundColor: colors.secondary,
                child: Icon(_roleIcon(role), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(speaker.label, style: theme.textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PersonaSpeakerRole>(
            initialValue: role,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final option in PersonaSpeakerRole.values)
                DropdownMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      Icon(_roleIcon(option), size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_roleLabel(context.l10n, option))),
                    ],
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      ),
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

String _roleLabel(AppLocalizations l10n, PersonaSpeakerRole role) =>
    switch (role) {
      PersonaSpeakerRole.user => l10n.personaRoleUser,
      PersonaSpeakerRole.personaSubject => l10n.personaRoleFriend,
      PersonaSpeakerRole.other => l10n.personaRoleOther,
      PersonaSpeakerRole.unknown => l10n.personaRoleUnknown,
    };

IconData _roleIcon(PersonaSpeakerRole role) => switch (role) {
  PersonaSpeakerRole.user => Icons.person_outline,
  PersonaSpeakerRole.personaSubject => Icons.face_outlined,
  PersonaSpeakerRole.other => Icons.people_outline,
  PersonaSpeakerRole.unknown => Icons.block_outlined,
};

String _messageTime(String sentAtLocal) =>
    sentAtLocal.length >= 16 ? sentAtLocal.substring(11, 16) : sentAtLocal;
