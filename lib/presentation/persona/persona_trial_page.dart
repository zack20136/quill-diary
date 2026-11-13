import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/persona/persona_prompts.dart';
import 'package:quill_diary/application/persona/persona_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_privacy_processor.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_labels.dart';
import 'package:quill_diary/presentation/ai/ai_connection_settings_dialog.dart';
import 'package:quill_diary/presentation/ai/ai_connection_setup_notice.dart';
import 'package:quill_diary/presentation/ai/ai_message_view.dart';
import 'package:quill_diary/shared/app_lifecycle.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';

class PersonaTrialPage extends ConsumerStatefulWidget {
  const PersonaTrialPage({
    super.key,
    required this.personId,
    required this.personaId,
    required this.cards,
    required this.connection,
  });
  final String personId;
  final String personaId;
  final Map<PersonaCardKind, PersonaCandidate> cards;
  final AiConnectionConfig connection;
  @override
  ConsumerState<PersonaTrialPage> createState() => _PersonaTrialPageState();
}

class _TrialMessage {
  _TrialMessage({
    required this.user,
    required this.visible,
    required this.outbound,
  });

  final bool user;
  String visible;
  String outbound;
}

class _PersonaTrialPageState extends ConsumerState<PersonaTrialPage>
    with WidgetsBindingObserver {
  final input = TextEditingController();
  final _inputScroll = ScrollController();
  final _messagesScroll = ScrollController();
  late AiConnectionConfig _connection = widget.connection;
  final messages = <_TrialMessage>[];
  ChatDiarySession? chat;
  UnlockedVaultSession? session;
  AiClient? client;
  bool busy = false;
  bool failed = false;
  bool backgrounded = false;
  int epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(effectiveAppSessionProvider, (_, next) {
      if (!identical(next.value?.session, session)) _clear();
    });
    ref.listenManual(
      personaDeletionsProvider.select((v) => v[widget.personId]),
      (_, _) => _clear(),
    );
    ref.listenManual(aiEnabledProvider, (_, enabled) {
      if (!enabled && busy) _stop();
    });
  }

  void _clear() {
    epoch++;
    client?.close();
    client = null;
    input.clear();
    messages.clear();
    chat = null;
    session = null;
    if (mounted) setState(() => busy = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (appLifecycleIsBackground(state)) {
      if (mounted) setState(() => backgrounded = true);
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => backgrounded = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    epoch++;
    client?.close();
    messages.clear();
    chat = null;
    input.dispose();
    _inputScroll.dispose();
    _messagesScroll.dispose();
    super.dispose();
  }

  void ensure(int version) {
    if (!mounted ||
        version != epoch ||
        session == null ||
        !identical(
          ref.read(effectiveAppSessionProvider).value?.session,
          session,
        )) {
      throw const FormatException('試聊已失效');
    }
  }

  Future<void> _send() async {
    if (busy ||
        input.text.trim().isEmpty ||
        ref.read(aiConnectionReadyProvider(_connection)).value != true) {
      return;
    }
    final l10n = context.l10n;
    final state = ref.read(effectiveAppSessionProvider).value;
    if (state?.session == null || !state!.isUnlocked) return;
    session = state.session;
    final version = ++epoch;
    setState(() {
      busy = true;
      failed = false;
    });
    AiClient? requestClient;
    try {
      ensure(version);
      if (!ref.read(aiEnabledProvider)) return;
      final settings = await ref.read(aiSettingsStoreProvider).read(session!);
      ensure(version);
      final people = await ref
          .read(vaultRepositoryProvider)
          .listPeople(session!);
      ensure(version);
      chat ??= ChatDiarySession(
        id: generateChatDiaryId(),
        vaultId: session!.vaultId,
        connectionConfig: _connection,
        hidePersonNames: settings.hidePersonNames,
        createdAt: DateTime.now(),
        date: DateOnly.fromDateTime(DateTime.now()).value,
      );
      final privacy = ChatDiaryPrivacyProcessor(chat!, people);
      final text = input.text;
      final protected = privacy.protect(text);
      final prompt = buildPersonaConversationPrompt(
        personId: widget.personId,
        personaId: widget.personaId,
        cards: widget.cards,
        people: people,
        privacy: privacy,
        l10n: l10n,
        guidance: settings.chatDiaryPrompts.guidanceOverride,
      );
      ensure(version);
      final key = await requireAiRequestKey(
        enabled: ref.read(aiEnabledProvider),
        connection: _connection,
        readApiKey: () =>
            ref.read(aiSettingsStoreProvider).readApiKey(_connection),
      );
      requestClient = ref.read(aiClientFactoryProvider)(_connection, key);
      ensure(version);
      client = requestClient;
      input.clear();
      final reply = _TrialMessage(user: false, visible: '', outbound: '');
      messages.add(
        _TrialMessage(user: true, visible: text, outbound: protected),
      );
      messages.add(reply);
      final history = [
        for (final message in messages)
          if (message.outbound.isNotEmpty)
            AiInputMessage(isUser: message.user, text: message.outbound),
      ];
      final output = StringBuffer();
      await for (final delta in requestClient.reply(prompt, history)) {
        ensure(version);
        output.write(delta);
        if (output.length > PersonaLimits.responseCodeUnits) {
          throw const FormatException('試聊回覆過長');
        }
        setState(() => reply.visible = privacy.restore(output.toString()));
      }
      ensure(version);
      if (output.isEmpty) throw const FormatException('試聊沒有回覆');
      reply.outbound = output.toString();
    } on Object {
      if (mounted && version == epoch) {
        if (messages.isNotEmpty &&
            !messages.last.user &&
            messages.last.outbound.isEmpty) {
          messages.removeLast();
        }
        setState(() => failed = true);
      }
    } finally {
      requestClient?.close();
      if (identical(client, requestClient)) client = null;
      if (mounted && version == epoch) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final bodyStyle = watchPersonalizationPreferences(ref).typography
        .bodyTextStyle(theme.textTheme);
    return Scaffold(
      appBar: AppBar(
        title: Text('${l.personaTrial} · ${l.personaTitle}'),
        leading: CloseButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: backgrounded
            ? const Center(child: Icon(Icons.lock_outline))
            : Column(
                children: [
                  _header(l, theme),
                  if (failed) _errorNotice(l, theme),
                  Expanded(
                    child: messages.isEmpty
                        ? _emptyState(l, theme)
                        : AppScrollbar(
                            controller: _messagesScroll,
                            child: ListView.builder(
                              controller: _messagesScroll,
                              physics: appBouncingScrollPhysics,
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                              itemCount: messages.length,
                              itemBuilder: (_, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: AiMessageView(
                                  text: messages[index].visible,
                                  isUser: messages[index].user,
                                  format: messages[index].user
                                      ? AiMessageFormat.plainText
                                      : AiMessageFormat.markdown,
                                ),
                              ),
                            ),
                          ),
                  ),
                  AiConnectionSetupNotice(
                    connection: _connection,
                    onOpenSettings: busy ? null : _settings,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  ),
                  _composer(l, theme, bodyStyle),
                ],
              ),
      ),
    );
  }

  Widget _header(AppLocalizations l, ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
    child: Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.12,
              ),
              foregroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.forum_outlined, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.personaTrialShortHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    aiChatModelLabel(l, _connection),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l.aiSettings,
              onPressed: busy ? null : _settings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _errorNotice(AppLocalizations l, ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Row(
      children: [
        Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
        const SizedBox(width: 8),
        Text(
          l.personaError,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
    ),
  );

  Widget _emptyState(AppLocalizations l, ThemeData theme) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            child: const Icon(Icons.chat_bubble_outline, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            l.personaTrialEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _composer(AppLocalizations l, ThemeData theme, TextStyle bodyStyle) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: input,
          builder: (context, value, _) {
            final canSend =
                value.text.trim().isNotEmpty &&
                ref.watch(aiConnectionReadyProvider(_connection)).value == true;
            return Container(
              key: const ValueKey('persona-trial-composer'),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppScrollbar(
                      controller: _inputScroll,
                      child: TextField(
                        controller: input,
                        scrollController: _inputScroll,
                        style: bodyStyle,
                        enabled: !busy,
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: l.personaTrialInput,
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            14,
                            8,
                            14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 6, 6),
                    child: IconButton.filled(
                      tooltip: busy ? l.aiStopGeneration : l.chatDiarySend,
                      onPressed: busy
                          ? _stop
                          : canSend
                          ? _send
                          : null,
                      icon: Icon(
                        busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

  Future<void> _settings() async {
    final openingSession = ref.read(effectiveAppSessionProvider).value?.session;
    final openingEpoch = epoch;
    if (openingSession == null || busy) return;
    final result = await showAiConnectionSettingsDialog(
      context,
      initialConnection: _connection,
    );
    if (!mounted ||
        result == null ||
        openingEpoch != epoch ||
        !identical(
          ref.read(effectiveAppSessionProvider).value?.session,
          openingSession,
        )) {
      return;
    }
    final stored = await ref.read(aiSettingsStoreProvider).read(openingSession);
    if (!mounted ||
        openingEpoch != epoch ||
        !identical(
          ref.read(effectiveAppSessionProvider).value?.session,
          openingSession,
        )) {
      return;
    }
    setState(() {
      _connection = (result.chatConnection ?? stored.connection.activeConfig)
          .captureRequestSnapshot();
      chat?.connectionConfig = _connection;
    });
  }

  void _stop() {
    epoch++;
    client?.close();
    if (messages.isNotEmpty &&
        !messages.last.user &&
        messages.last.outbound.isEmpty) {
      messages.removeLast();
    }
    setState(() => busy = false);
  }
}
