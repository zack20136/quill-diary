import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_prompt_localizations.dart';
import 'package:quill_diary/application/ai/ai_prompts.dart';
import 'package:quill_diary/application/persona/persona_prompts.dart';
import 'package:quill_diary/domain/ai/ai_request.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_prompt_dialog.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_section.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

class AiPromptSettingsDialog extends StatefulWidget {
  const AiPromptSettingsDialog({
    super.key,
    required this.chat,
    required this.organization,
    required this.onChanged,
  });

  final ChatDiaryPromptSettings chat;
  final DiaryOrganizationPromptSettings organization;
  final void Function(ChatDiaryPromptSettings, DiaryOrganizationPromptSettings)
  onChanged;

  @override
  State<AiPromptSettingsDialog> createState() => _AiPromptSettingsDialogState();
}

class _AiPromptSettingsDialogState extends State<AiPromptSettingsDialog> {
  late var _chat = widget.chat;
  late var _organization = widget.organization;
  AppLocalizations get _l10n => context.l10n;

  Widget _tile(
    AiPromptVariant variant, {
    required Key fieldKey,
    String Function(AppLocalizations)? help,
    String? custom,
    ValueChanged<String?>? onEdit,
    List<AiPromptVariant> variants = const [],
    bool fullPreview = false,
  }) => ListTile(
    key: ValueKey<Key>(fieldKey),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    leading: fullPreview ? const Icon(Icons.preview_outlined, size: 22) : null,
    minLeadingWidth: 22,
    horizontalTitleGap: 12,
    tileColor: fullPreview
        ? Color.alphaBlend(
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
            Theme.of(context).colorScheme.surfaceContainerLow,
          )
        : null,
    iconColor: fullPreview ? Theme.of(context).colorScheme.primary : null,
    titleTextStyle: fullPreview
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium,
    title: Text(variant.label(_l10n)),
    subtitle: onEdit == null
        ? null
        : Text(custom == null ? _l10n.aiPromptBuiltIn : _l10n.aiPromptCustom),
    trailing: const Icon(Icons.chevron_right),
    onTap: () async {
      final edited = await showAiPromptDialog(
        context,
        title: variant.label,
        help: help,
        defaultPrompt: variant.prompt,
        fieldKey: fieldKey,
        readOnly: onEdit == null,
        customText: custom,
        variants: variants,
      );
      if (mounted && edited != null && onEdit != null) {
        setState(() => onEdit(edited.customText));
        widget.onChanged(_chat, _organization);
      }
    },
  );

  Widget _readOnly(
    String id,
    String Function(AppLocalizations) label,
    String Function(AppLocalizations) prompt,
  ) => _tile((
    label: label,
    prompt: (language) => prompt(localizationsFor(language)),
  ), fieldKey: ValueKey(id));

  Widget _fullPreview(String id, List<AiPromptVariant> variants) => _tile(
    (label: (l) => l.aiPromptFullPreview, prompt: variants.first.prompt),
    fieldKey: ValueKey(id),
    help: (l) => l.aiPromptPreviewHelp,
    variants: variants,
    fullPreview: true,
  );

  Widget _chatPrompt(
    ChatDiaryPromptPurpose purpose,
    String Function(AppLocalizations) label, {
    String Function(AppLocalizations)? help,
  }) {
    final custom = switch (purpose) {
      ChatDiaryPromptPurpose.personality => _chat.personalityOverride,
      ChatDiaryPromptPurpose.conversationGuidance => _chat.guidanceOverride,
      ChatDiaryPromptPurpose.generationGuidance => _chat.generationOverride,
      _ => null,
    };
    final editable =
        purpose == ChatDiaryPromptPurpose.personality ||
        purpose == ChatDiaryPromptPurpose.conversationGuidance ||
        purpose == ChatDiaryPromptPurpose.generationGuidance;
    return _tile(
      (
        label: label,
        prompt: (language) => resolveChatDiaryPrompt(
          purpose,
          language,
          const ChatDiaryPromptSettings(),
        ),
      ),
      fieldKey: ValueKey(purpose),
      help: help,
      custom: custom,
      onEdit: editable
          ? (value) => _chat = ChatDiaryPromptSettings(
              personalityOverride: purpose == ChatDiaryPromptPurpose.personality
                  ? value
                  : _chat.personalityOverride,
              guidanceOverride:
                  purpose == ChatDiaryPromptPurpose.conversationGuidance
                  ? value
                  : _chat.guidanceOverride,
              generationOverride:
                  purpose == ChatDiaryPromptPurpose.generationGuidance
                  ? value
                  : _chat.generationOverride,
              selectedPersona: _chat.selectedPersona,
            )
          : null,
    );
  }

  Widget _organizationPrompt({required bool generate}) => _tile(
    (
      label: generate
          ? (l) => l.organizationGenerationLabel
          : (l) => l.organizationConversationLabel,
      prompt: (language) => resolveDiaryOrganizationPrompt(
        generate: generate,
        language: language,
        settings: const DiaryOrganizationPromptSettings(),
      ),
    ),
    fieldKey: ValueKey(
      generate
          ? 'organization-generation-prompt'
          : 'organization-conversation-prompt',
    ),
    help: generate ? (l) => l.organizationGenerationHelp : null,
    custom: generate
        ? _organization.generationOverride
        : _organization.conversationOverride,
    onEdit: (value) => _organization = DiaryOrganizationPromptSettings(
      conversationOverride: generate
          ? _organization.conversationOverride
          : value,
      generationOverride: generate ? value : _organization.generationOverride,
    ),
  );

  String _targetName(AppLocalizations l, PersonaUpdateTarget target) =>
      switch (target) {
        PersonaUpdateTarget.memory => l.personaMemory,
        PersonaUpdateTarget.tone => l.personaTone,
        PersonaUpdateTarget.both => l.aiPromptBothCards,
      };

  Widget _section(String title, List<Widget> tiles) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      AppDialogSection(
        child: Column(
          children: [
            for (final (index, tile) in tiles.indexed) ...[
              if (index > 0) const Divider(height: 1),
              tile,
            ],
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AppDialogShell(
    title: _l10n.aiPromptsTitle,
    fillHeight: true,
    content: AppScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section(_l10n.chatDiaryTitle, [
            _fullPreview('chat-full-prompt', [
              (
                label: (l) => l.aiRequestPreviewChat,
                prompt: (language) => resolveChatDiaryPrompt(
                  ChatDiaryPromptPurpose.conversation,
                  language,
                  _chat,
                ),
              ),
              (
                label: (l) => l.chatDiaryGenerateDiary,
                prompt: (language) => resolveChatDiaryPrompt(
                  ChatDiaryPromptPurpose.generation,
                  language,
                  _chat,
                ),
              ),
            ]),
            _chatPrompt(
              ChatDiaryPromptPurpose.conversationRules,
              (l) => l.chatDiaryRulesLabel,
            ),
            _chatPrompt(
              ChatDiaryPromptPurpose.conversationGuidance,
              (l) => l.chatDiaryGuidanceLabel,
              help: (l) => l.chatDiaryGuidanceHelp,
            ),
            _chatPrompt(
              ChatDiaryPromptPurpose.personality,
              (l) => l.chatDiaryPersonalityLabel,
              help: (l) => l.chatDiaryPersonalityHelp,
            ),
            _chatPrompt(
              ChatDiaryPromptPurpose.generationRules,
              (l) => l.chatDiaryGenerationRulesLabel,
            ),
            _chatPrompt(
              ChatDiaryPromptPurpose.generationGuidance,
              (l) => l.chatDiaryGenerationGuidanceLabel,
              help: (l) => l.chatDiaryGenerationGuidanceHelp,
            ),
          ]),
          _section(_l10n.organizationTitle, [
            _fullPreview('organization-full-prompt', [
              for (final generate in [false, true])
                (
                  label: generate
                      ? (l) => l.organizationGenerationLabel
                      : (l) => l.organizationConversationLabel,
                  prompt: (language) => resolveDiaryOrganizationInstructions(
                    generate: generate,
                    language: language,
                    settings: _organization,
                  ),
                ),
            ]),
            _tile((
              label: (l) => l.chatDiaryRulesLabel,
              prompt: (language) => [
                localizationsFor(language).organizationRules,
                localizationsFor(language).organizationDiscussionRulesPrompt,
                localizationsFor(language).organizationDraftRulesPrompt,
              ].join('\n\n'),
            ), fieldKey: const ValueKey('organization-rules-prompt')),
            _organizationPrompt(generate: false),
            _organizationPrompt(generate: true),
            _readOnly(
              'organization-quick-prompts',
              (l) => l.aiPromptQuickRequests,
              (l) => [
                '${l.organizationPolish}\n${l.organizationPolishRequest}',
                '${l.organizationCondense}\n${l.organizationCondenseRequest}',
                '${l.organizationStructure}\n${l.organizationStructureRequest}',
                '${l.organizationElaborate}\n${l.organizationElaborateRequest}',
              ].join('\n\n'),
            ),
          ]),
          _section(_l10n.personaTitle, [
            _fullPreview('persona-full-prompt', [
              (
                label: (l) => l.aiRequestPreviewChat,
                prompt: (language) {
                  final l = localizationsFor(language);
                  return personaConversationInstructions(
                    l,
                    instructions: personaFixedInstructions(
                      l10n: l,
                      guidance: _chat.guidanceOverride,
                    ),
                    subject: '〈${l.personaSubjectHeading}〉',
                    memory: '〈${l.personaMemory}〉',
                    tone: '〈${l.personaTone}〉',
                  );
                },
              ),
              for (final target in PersonaUpdateTarget.values) ...[
                (
                  label: (l) => l.aiPromptStageTarget(
                    l.personaIntegrating,
                    _targetName(l, target),
                  ),
                  prompt: (language) => personaGenerationInstructions(
                    localizationsFor(language),
                    target,
                  ),
                ),
                (
                  label: (l) => l.aiPromptStageTarget(
                    l.personaExtracting,
                    _targetName(l, target),
                  ),
                  prompt: (language) => personaExtractionInstructions(
                    localizationsFor(language),
                    target,
                  ),
                ),
                (
                  label: (l) => l.aiPromptStageTarget(
                    l.aiPromptBatchRetry,
                    _targetName(l, target),
                  ),
                  prompt: (language) => personaExtractionInstructions(
                    localizationsFor(language),
                    target,
                    retry: true,
                  ),
                ),
                (
                  label: (l) => l.aiPromptStageTarget(
                    l.personaCompacting,
                    _targetName(l, target),
                  ),
                  prompt: (language) => personaGenerationInstructions(
                    localizationsFor(language),
                    target,
                    compact: true,
                  ),
                ),
              ],
            ]),
            _readOnly(
              'persona-conversation-prompt',
              (l) => l.personaBaseLabel,
              (l) => personaFixedInstructions(l10n: l),
            ),
            _readOnly(
              'persona-memory-prompt',
              (l) => l.personaMemory,
              (l) => l.personaMemoryUpdatePrompt,
            ),
            _readOnly(
              'persona-tone-prompt',
              (l) => l.personaTone,
              (l) => l.personaToneUpdatePrompt,
            ),
            _readOnly(
              'persona-batch-prompt',
              (l) => l.personaBatchSystemPrompt,
              (l) => l.personaExtractionRules,
            ),
            _readOnly(
              'persona-output-prompt',
              (l) => l.aiPromptOutputFormat,
              (l) => l.personaOutputRules(
                PersonaLimits.memoryCodeUnits,
                PersonaLimits.toneCodeUnits,
              ),
            ),
          ]),
          _section(_l10n.aiApiSection, [
            _readOnly(
              'connection-test-prompt',
              (l) => l.aiTestConnection,
              (_) => aiConnectionTestPrompt,
            ),
          ]),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_l10n.commonActionClose),
      ),
    ],
  );
}
