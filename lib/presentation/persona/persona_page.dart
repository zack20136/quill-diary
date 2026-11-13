import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/persona/persona_controller.dart';
import 'package:quill_diary/application/persona/persona_material.dart';
import 'package:quill_diary/application/persona/persona_prompts.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/diary/diary_entry_summary.dart';
import 'package:quill_diary/domain/diary_organization/organization_diff.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_chat_import.dart';
import 'package:quill_diary/domain/persona/persona_content.dart';
import 'package:quill_diary/domain/persona/persona_privacy.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/shared/picked_file_materializer.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_chat_model_picker.dart';
import 'package:quill_diary/presentation/ai/ai_connection_settings_dialog.dart';
import 'package:quill_diary/presentation/ai/ai_connection_setup_notice.dart';
import 'package:quill_diary/presentation/ai/ai_feature_error_panel.dart';
import 'package:quill_diary/presentation/ai/ai_generation_card.dart';
import 'package:quill_diary/presentation/ai/ai_preview_text_section.dart';
import 'package:quill_diary/presentation/diary_organization/organization_review.dart';
import 'package:quill_diary/presentation/persona/persona_chat_rule_dialog.dart';
import 'package:quill_diary/presentation/persona/persona_content_editor.dart';
import 'package:quill_diary/presentation/persona/persona_labels.dart';
import 'package:quill_diary/presentation/persona/persona_material_dialogs.dart';
import 'package:quill_diary/presentation/persona/persona_trial_page.dart';
import 'package:quill_diary/shared/app_lifecycle.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/date_picker/app_date_picker_dialog.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/private_text_spans.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_loading_state.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

const _cardOrder = [PersonaCardKind.tone, PersonaCardKind.memory];

class PersonaPage extends ConsumerStatefulWidget {
  const PersonaPage({super.key, required this.personId});
  final String personId;
  @override
  ConsumerState<PersonaPage> createState() => _PersonaPageState();
}

class _PersonaPageState extends ConsumerState<PersonaPage>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  final _dialogs = <Route<dynamic>>{};
  final _scroll = ScrollController();
  final _materialsScroll = ScrollController();
  final _reviewScroll = ScrollController();
  final _savedScroll = ScrollController();
  Future<List<DiaryEntrySummary>>? _results;
  Timer? _searchTimer;
  bool _backgrounded = false;
  bool _acting = false;
  bool _needsAiSettings = false;
  String? _guidanceOverride;
  bool _selectedOnly = false;
  int _editorVersion = 0;
  PersonaController get _controller =>
      ref.read(personaControllerProvider(widget.personId));
  TextStyle get _bodyStyle =>
      watchPersonalizationPreferences(ref).typography
          .bodyTextStyle(Theme.of(context).textTheme);
  TextStyle? get _hintStyle =>
      Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
  Map<String, String> get _personNames => {
    for (final person in ref.read(peopleListProvider).value ?? [])
      person.id: person.name,
  };
  PersonaContent _content(PersonaCandidate card) => PersonaContent(
    card,
    _personNames,
    unknownPerson: context.l10n.personaUnknownPerson,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(effectiveAppSessionProvider, (_, next) {
      if (next.value?.isUnlocked != true) {
        _dismissDialogs();
        _search.clear();
        _results = null;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_initialize());
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_initialize()),
    );
  }

  Future<void> _initialize() async {
    await _controller.load();
    if (!mounted || _controller.session == null || _controller.loading) return;
    final session = _controller.session;
    try {
      await _loadGuidanceOverride();
      if (!mounted || !identical(_controller.session, session)) return;
      if (_controller.record == null && !_controller.failed) {
        await _run(() => _controller.begin(PersonaUpdateTarget.both));
      }
    } on Object catch (error) {
      _reportError(error, session);
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadGuidanceOverride() async {
    final session = _controller.session;
    if (session == null) return;
    final settings = await ref.read(aiSettingsStoreProvider).read(session);
    if (!mounted || !identical(_controller.session, session)) return;
    setState(
      () => _guidanceOverride = settings.chatDiaryPrompts.guidanceOverride,
    );
  }

  void _dismissDialogs() {
    for (final route in _dialogs.toList().reversed) {
      if (route.isActive) route.navigator?.removeRoute(route);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (appLifecycleIsBackground(state)) {
      _dismissDialogs();
      if (mounted) setState(() => _backgrounded = true);
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _backgrounded = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchTimer?.cancel();
    _search.dispose();
    _scroll.dispose();
    _materialsScroll.dispose();
    _reviewScroll.dispose();
    _savedScroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_acting) return;
    final session = _controller.session;
    setState(() => _acting = true);
    try {
      await action();
    } on Object catch (error) {
      _reportError(error, session);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _reportError(Object error, UnlockedVaultSession? session) {
    if (!mounted ||
        session == null ||
        !identical(_controller.session, session)) {
      return;
    }
    if (error is AiFailure && error.code == AiErrorCode.settings) {
      setState(() => _needsAiSettings = true);
    } else {
      showAppFeedbackToast(
        context,
        context.l10n.personaError,
        tone: AppFeedbackTone.error,
      );
    }
  }

  Future<void> _recoverAiSettings() async {
    final session = _controller.session;
    if (session == null) return;
    final wasConfirmation = _controller.draft?.step == PersonaStep.confirmation;
    final result = await _dialog<AiConnectionSettingsResult>(
      const AiConnectionSettingsDialog(),
    );
    if (!mounted ||
        result == null ||
        !identical(_controller.session, session)) {
      return;
    }
    await _loadGuidanceOverride();
    if (!mounted) return;
    setState(() => _needsAiSettings = false);
    if (_controller.record == null) {
      await _controller.begin(PersonaUpdateTarget.both);
    } else if (_controller.draft != null) {
      final settings = await ref.read(aiSettingsStoreProvider).read(session);
      if (!mounted || !identical(_controller.session, session)) return;
      await _controller.selectModel(
        ChatModelOption(connectionConfig: settings.connection.activeConfig),
      );
      if (wasConfirmation &&
          mounted &&
          identical(_controller.session, session)) {
        await _controller.prepare(context.l10n);
      }
    }
    if (mounted && identical(_controller.session, session)) {
      setState(() => _needsAiSettings = false);
    }
  }

  Future<T?> _dialog<T>(Widget child) async {
    final session = _controller.session;
    if (session == null || _backgrounded) return null;
    final route = appDialogRoute<T>(
      context: context,
      useSafeArea: false,
      builder: (_) => identical(session, _controller.session) && !_backgrounded
          ? child
          : const SizedBox.shrink(),
    );
    _dialogs.add(route);
    try {
      return await Navigator.of(context, rootNavigator: true).push(route);
    } finally {
      _dialogs.remove(route);
    }
  }

  Future<bool> _confirm(String title, String body) => showAppConfirmDialog(
    context: context,
    title: title,
    content: Text(body),
    cancelLabel: context.l10n.commonActionCancel,
    confirmLabel: title,
    confirmStyle: AppConfirmStyle.destructive,
  );

  Future<void> _mask(
    String title,
    String text,
    List<PrivateTextRange> ranges,
    void Function(List<PrivateTextRange>) update, {
    void Function()? checked,
    PersonaContent? content,
  }) async {
    final session = _controller.session;
    final reviewed = await _dialog<bool>(
      PersonaMaskDialog(
        title: title,
        text: content?.text ?? text,
        ranges: content?.visibleRanges(ranges) ?? ranges,
        references:
            content?.references.map((r) => r.visible).toList() ?? const [],
        onChanged: (value) {
          if (identical(session, _controller.session)) {
            update(content?.sourceRanges(value) ?? value);
            _controller.resetToMaterials();
          }
        },
      ),
    );
    if (!identical(session, _controller.session)) return;
    if (reviewed == true) checked?.call();
    await _controller.persist();
  }

  Future<void> _pasteOrPick(bool pick) async {
    final session = _controller.session;
    if (session == null || _controller.record == null) return;
    final texts = <String>[];
    if (pick) {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'json'],
      );
      if (files.isEmpty) return;
      var totalBytes = 0;
      for (final file in files) {
        final materialized = await PickedFileMaterializer().materialize(
          file,
          fallbackBaseName: 'chat.txt',
          alwaysCopyToTemp: false,
        );
        try {
          final length = await materialized.file.length();
          totalBytes += length;
          if (length > PersonaLimits.importBytes ||
              totalBytes > PersonaLimits.importBytes) {
            throw const FormatException('匯入檔案過大');
          }
          texts.add(utf8.decode(await materialized.file.readAsBytes()));
        } finally {
          if (materialized.shouldDeleteAfterUse) {
            await materialized.file.delete();
          }
        }
      }
    } else {
      final text = await _dialog<String>(const PersonaPasteDialog());
      if (text != null) texts.add(text);
    }
    if (!mounted || texts.isEmpty || !identical(session, _controller.session)) {
      return;
    }
    if (texts.any(
      (text) => utf8.encode(text).length > PersonaLimits.importBytes,
    )) {
      throw const FormatException('匯入文字過大');
    }
    final reports = <({PersonaChatImport chat, int skippedLines})>[];
    final raws = <PersonaChatImport>[];
    for (final text in texts) {
      if (!mounted || !identical(session, _controller.session)) return;
      final builtin = tryBuiltinPersonaChat(
        text,
        vaultId: session.vaultId,
        personId: widget.personId,
        personaId: _controller.record!.personaId,
      );
      if (builtin != null) {
        reports.add(builtin);
        continue;
      }
      final chosen = await _dialog<PersonaChatImport>(
        PersonaChatRuleDialog(
          input: text,
          vaultId: session.vaultId,
          personId: widget.personId,
          personaId: _controller.record!.personaId,
        ),
      );
      if (!mounted ||
          chosen == null ||
          !identical(session, _controller.session)) {
        return;
      }
      raws.add(chosen);
    }
    if (reports.isNotEmpty) {
      final report = combinePersonaChatReports(
        reports,
        vaultId: session.vaultId,
        personId: widget.personId,
        personaId: _controller.record!.personaId,
      );
      if (report.skippedLines > 0 &&
          mounted &&
          identical(session, _controller.session)) {
        showAppFeedbackToast(
          context,
          context.l10n.personaImportSkippedLines(report.skippedLines),
          tone: AppFeedbackTone.warning,
        );
      }
      final roles = await _dialog<bool>(PersonaRolesDialog(chat: report.chat));
      if (!mounted ||
          roles != true ||
          !identical(session, _controller.session)) {
        return;
      }
      await _controller.attachImport(report.chat);
    }
    for (final raw in raws) {
      if (!mounted || !identical(session, _controller.session)) return;
      await _controller.attachImport(raw);
    }
  }

  Widget _section(String title, List<Widget> children, {Widget? trailing}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: PageStyle.sectionGap),
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionHeader(title: title, trailing: trailing),
              const SizedBox(height: 12),
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          ),
        ),
      );

  Widget _ready() {
    final l = context.l10n;
    return AppScrollbar(
      controller: _savedScroll,
      child: ListView(
        controller: _savedScroll,
        physics: appBouncingScrollPhysics,
        key: const ValueKey('persona-saved'),
        padding: const EdgeInsets.fromLTRB(
          PageStyle.pageHorizontalPadding,
          PageStyle.pageTopPadding,
          PageStyle.pageHorizontalPadding,
          PageStyle.pageBottomPadding,
        ),
        children: [
          _replyRules(),
          AppInsetPanel(
            child: Text(
              l.personaUsageHint,
              style: _hintStyle?.copyWith(height: 1.45),
            ),
          ),
          const SizedBox(height: PageStyle.sectionGap),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: ref.watch(aiEnabledProvider)
                  ? () =>
                        _run(() => _controller.begin(PersonaUpdateTarget.both))
                  : null,
              child: Text(l.personaUpdateBoth),
            ),
          ),
          const SizedBox(height: PageStyle.sectionGap),
          for (final kind in _cardOrder) ...[
            _savedCard(kind),
            const SizedBox(height: PageStyle.sectionGap),
          ],
        ],
      ),
    );
  }

  IconData _cardIcon(PersonaCardKind kind) => kind == PersonaCardKind.tone
      ? Icons.forum_outlined
      : Icons.history_rounded;

  Widget _savedCard(PersonaCardKind kind) {
    final l = context.l10n;
    final card = _controller.record!.cards![kind]!;
    final content = _content(card);
    final target = kind == PersonaCardKind.memory
        ? PersonaUpdateTarget.memory
        : PersonaUpdateTarget.tone;
    final aiEnabled = ref.watch(aiEnabledProvider);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSectionHeader(
                  title: personaCardLabel(l, kind),
                  description: _cardDescription(l, kind),
                  icon: _cardIcon(kind),
                ),
                const SizedBox(height: 12),
                _SavedPersonaText(text: content.text, style: _bodyStyle),
                if (content.hasUnresolvedReferences) ...[
                  const SizedBox(height: 10),
                  Text(l.personaUnresolvedReferenceHint, style: _hintStyle),
                ],
                const SizedBox(height: 12),
                Text(
                  l.personaUpdatedAt(
                    DisplayFormat.formatDateTimeWithoutWeekday(
                      l,
                      card.updatedAt,
                    ),
                  ),
                  style: _hintStyle,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _SavedPersonaActions(
            editLabel: l.personaEdit,
            updateLabel: l.personaUpdateContent,
            onEdit: aiEnabled
                ? () => _run(() => _controller.begin(target, edit: true))
                : null,
            onUpdate: aiEnabled
                ? () => _run(() => _controller.begin(target))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _replyRules() => Padding(
    padding: const EdgeInsets.only(bottom: PageStyle.sectionGap),
    child: _CollapsibleCard(
      title: context.l10n.personaBaseLabel,
      text: personaFixedInstructions(
        l10n: context.l10n,
        guidance: _guidanceOverride,
      ),
      style: _bodyStyle,
    ),
  );

  String _cardDescription(AppLocalizations l, PersonaCardKind kind) =>
      kind == PersonaCardKind.memory
      ? l.personaMemoryDescription
      : l.personaToneDescription;

  Widget _privacySettings() {
    final l = context.l10n;
    final draft = _controller.draft!;
    final kinds = _cardOrder.where(draft.target.kinds.contains).toList();
    return _section(l.personaInspect, [
      Row(
        children: [
          Expanded(child: Text(l.chatDiaryHidePeople)),
          Switch(
            value: draft.hidePersonNames,
            onChanged: (value) {
              draft.hidePersonNames = value;
              _controller.resetToMaterials();
            },
          ),
        ],
      ),
      Text(l.personaHideHint, style: _hintStyle),
      if (_controller.record?.cards != null)
        Text(l.personaIncludeCurrentHint, style: _hintStyle),
      if (_controller.record?.cards != null)
        Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < kinds.length; index++) ...[
                if (index > 0)
                  const Divider(height: 1, indent: 12, endIndent: 12),
                ListTile(
                  dense: true,
                  leading: Checkbox(
                    key: ValueKey(
                      'persona-include-current-${kinds[index].name}',
                    ),
                    value: draft.includeCurrent[kinds[index]] ?? false,
                    onChanged: _acting || _controller.busy
                        ? null
                        : (value) => _controller.setIncludeCurrent(
                            kinds[index],
                            value ?? false,
                          ),
                  ),
                  title: Text(
                    kinds[index] == PersonaCardKind.memory
                        ? l.personaIncludeCurrentMemory
                        : l.personaIncludeCurrentTone,
                  ),
                  subtitle: Text(
                    l.personaHiddenCount(
                      draft.cardHiddenRanges[kinds[index]]?.length ?? 0,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _run(
                    () => _mask(
                      personaCardLabel(l, kinds[index]),
                      _controller.record!.cards![kinds[index]]!.text,
                      draft.cardHiddenRanges[kinds[index]] ?? [],
                      (ranges) => draft.cardHiddenRanges[kinds[index]] = ranges,
                      content: _content(
                        _controller.record!.cards![kinds[index]]!,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
    ]);
  }

  Widget _materials() {
    final l = context.l10n;
    final d = _controller.draft!;
    final needReview = _controller.materialsNeedReview;
    return AppScrollbar(
      controller: _materialsScroll,
      child: CustomScrollView(
        controller: _materialsScroll,
        physics: appBouncingScrollPhysics,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AppInsetPanel(
                      child: Text(l.personaPrivacyHint, style: _hintStyle),
                    ),
                  ),
                ),
                if (_controller.missingDiaries)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(l.personaMissingDiaries),
                    ),
                  ),
                if (needReview)
                  SliverToBoxAdapter(
                    child: AppInsetPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.personaSourceChangedHint),
                          TextButton(
                            onPressed: () => setState(() {
                              _selectedOnly = true;
                              _searchTimer?.cancel();
                              _search.clear();
                              _results = null;
                            }),
                            child: Text(l.personaSelectedOnly),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: _privacySettings()),
                SliverToBoxAdapter(child: _chatImportSection(l, d)),
                _diarySection(l, d),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatImportSection(AppLocalizations l, PersonaDraft draft) {
    return _section(
      l.personaChats,
      [
        AppActionButton(
          label: l.personaChooseFile,
          icon: Icons.upload_file,
          appearance: AppActionButtonAppearance.tonal,
          fullWidth: true,
          onPressed: () => _run(() => _pasteOrPick(true)),
        ),
        AppActionButton(
          label: l.personaPaste,
          icon: Icons.paste,
          appearance: AppActionButtonAppearance.tonal,
          fullWidth: true,
          onPressed: () => _run(() => _pasteOrPick(false)),
        ),
        for (final source in draft.chats) _chatMaterial(source),
      ],
      trailing: IconButton(
        tooltip: l.personaChatExportHelp,
        onPressed: () => _dialog<void>(const PersonaChatExportHelpDialog()),
        icon: const Icon(Icons.info_outline_rounded),
      ),
    );
  }

  Widget _diarySection(AppLocalizations l, PersonaDraft draft) {
    return AppSliverSectionCard(
      title: l.personaDiaries,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(l.personaDiarySelectionHint, style: _hintStyle),
          ),
        ),
        SliverToBoxAdapter(
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: l.personaSearch,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (query) {
              _searchTimer?.cancel();
              _searchTimer = Timer(const Duration(milliseconds: 300), () {
                if (!mounted || _controller.session == null) return;
                setState(
                  () => _results = query.trim().isEmpty
                      ? null
                      : ref
                            .read(vaultRepositoryProvider)
                            .searchEntries(query.trim()),
                );
              });
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: Text('${l.personaSelectedOnly} (${draft.diaries.length})'),
              selected: _selectedOnly,
              onSelected: (value) => setState(() => _selectedOnly = value),
            ),
          ),
        ),
        _diaryEntrySliver(l),
      ],
    );
  }

  Widget _diaryEntrySliver(AppLocalizations l) {
    if (_results != null) {
      return FutureBuilder<List<DiaryEntrySummary>>(
        future: _results,
        builder: (_, snapshot) => snapshot.hasData
            ? _diaryRows(snapshot.data!)
            : SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: snapshot.hasError
                      ? Text(l.personaError)
                      : const LinearProgressIndicator(),
                ),
              ),
      );
    }
    if (_selectedOnly) return _diaryRows(const []);
    return ref
        .watch(personRelatedEntriesProvider(widget.personId))
        .when(
          data: _diaryRows,
          error: (_, _) => SliverToBoxAdapter(child: Text(l.personaError)),
          loading: () =>
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
        );
  }

  Widget _diaryRows(List<DiaryEntrySummary> matches) {
    final sources = {
      for (final source in _controller.draft!.diaries) source.entryId: source,
    };
    final summaries = {for (final summary in matches) summary.id: summary};
    final ids = _selectedOnly
        ? sources.keys
              .where(
                (id) =>
                    _search.text.trim().isEmpty || summaries.containsKey(id),
              )
              .toList()
        : matches.map((entry) => entry.id).toList();
    if (ids.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(context.l10n.personaNoRelatedDiaries),
        ),
      );
    }
    return SliverList.builder(
      itemCount: ids.length,
      itemBuilder: (_, index) {
        final bodyStyle = _bodyStyle;
        final id = ids[index];
        final source = sources[id];
        final summary = summaries[id];
        final entry = _controller.entries[id];
        final title =
            summary?.title ??
            entry?.title ??
            summary?.date.value ??
            entry?.date.value ??
            context.l10n.personaSourceUnavailable;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Checkbox(
            value: source != null,
            onChanged: (selected) =>
                _run(() => _controller.selectDiary(id, selected == true)),
          ),
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            source != null && entry == null
                ? context.l10n.personaSourceUnavailable
                : source?.needsReview == true
                ? context.l10n.personaChangedDiary
                : '${summary?.date.value ?? entry?.date.value ?? ''}${source == null || source.hiddenRanges.isEmpty ? '' : ' · ${context.l10n.personaHiddenCount(source.hiddenRanges.length)}'}',
          ),
          trailing: source != null && entry == null
              ? IconButton(
                  tooltip: context.l10n.personaRemove,
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      _run(() => _controller.selectDiary(id, false)),
                )
              : Icon(
                  source != null && source.hiddenRanges.isNotEmpty
                      ? Icons.visibility_off_outlined
                      : Icons.chevron_right,
                  size: 20,
                ),
          onTap: source != null && entry == null
              ? null
              : () => _run(() async {
                  if (source != null) {
                    await _mask(
                      title,
                      entry!.markdownBody,
                      source.hiddenRanges,
                      (ranges) => source.hiddenRanges = ranges,
                      checked: () {
                        source.needsReview = false;
                        _controller.schedulePersist();
                      },
                    );
                  } else {
                    final session = _controller.session;
                    final value = await ref
                        .read(vaultRepositoryProvider)
                        .loadEntry(session!, id);
                    if (value == null ||
                        !mounted ||
                        !identical(session, _controller.session)) {
                      return;
                    }
                    await _dialog<void>(
                      PersonaDiaryPreviewDialog(
                        title: title,
                        body: value.markdownBody,
                        bodyStyle: bodyStyle,
                      ),
                    );
                  }
                }),
        );
      },
    );
  }

  Widget _chatMaterial(PersonaChatSource source) {
    final l = context.l10n;
    final chat = _controller.imports[source.importId];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.chat_outlined),
      title: Text(
        chat == null
            ? l.personaSourceUnavailable
            : DisplayFormat.formatDateTimeWithoutWeekday(l, chat.importedAt),
      ),
      subtitle: chat == null
          ? null
          : Text(
              chat.isRaw
                  ? l.personaChatRawLabel
                  : l.personaIncludedCount(
                      chat
                          .messagesInWindow(source)
                          .where((m) => !source.excluded.contains(m.id))
                          .length,
                    ),
            ),
      trailing: IconButton(
        tooltip: l.personaRemove,
        icon: const Icon(Icons.close),
        onPressed: () => _run(() => _controller.removeImport(source.importId)),
      ),
      onTap: chat == null
          ? null
          : () => chat.isRaw ? _openRawChat(source) : _openChatMaterial(source),
    );
  }

  Future<void> _openRawChat(PersonaChatSource source) async {
    final current = _controller.imports[source.importId];
    if (current == null) return;
    final session = _controller.session;
    final edited = await _dialog<PersonaChatImport>(
      PersonaChatRuleDialog(
        input: current.rawText,
        vaultId: current.vaultId,
        personId: current.personId,
        personaId: current.personaId,
        existing: current,
      ),
    );
    if (edited == null || !identical(session, _controller.session)) return;
    await _run(() => _controller.updateImport(edited));
  }

  Future<void> _openChatMaterial(PersonaChatSource source) => _dialog<void>(
    PersonaChatMaterialPage(
      source: source,
      readChat: () => _controller.imports[source.importId]!,
      bodyStyle: _bodyStyle,
      onEditRoles: () async {
        final chat = PersonaChatImport.fromJson(
          jsonDecode(jsonEncode(_controller.imports[source.importId]!.toJson()))
              as Map<String, dynamic>,
        );
        final session = _controller.session;
        final accepted = await _dialog<bool>(PersonaRolesDialog(chat: chat));
        if (!mounted || !identical(session, _controller.session)) return;
        if (accepted == true) {
          await _run(() => _controller.updateImport(chat));
        }
      },
      onClearDate: (start) {
        if (_controller.busy) return;
        if (start) {
          source.fromDate = null;
        } else {
          source.toDate = null;
        }
        _controller.resetToMaterials();
      },
      onPickDate: (start) =>
          _chooseDate(source, _controller.imports[source.importId]!, start),
      onToggleDate: (messages, included) {
        if (_controller.busy) return;
        for (final message in messages) {
          if (included) {
            source.excluded.remove(message.id);
          } else {
            source.excluded.add(message.id);
          }
        }
        _controller.resetToMaterials();
      },
      onEditDate: (date, messages) => _run(
        () => _openChatDateMaterial(
          source,
          _controller.imports[source.importId]!,
          date,
          messages,
        ),
      ),
    ),
  );

  Future<void> _openChatDateMaterial(
    PersonaChatSource source,
    PersonaChatImport chat,
    String date,
    List<PersonaImportMessage> messages,
  ) async {
    final session = _controller.session;
    final speakers = {for (final speaker in chat.speakers) speaker.id: speaker};
    final messageIds = messages.map((message) => message.id).toSet();
    final edited = await _dialog<List<PersonaChatDateEditResult>>(
      PersonaChatDateEditorDialog(
        title: date,
        messages: [
          for (final message in messages)
            PersonaChatDateEditorMessage(
              messageId: message.id,
              speaker: speakers[message.speakerId]!.label,
              sentAtLocal: message.sentAtLocal,
              text: message.text,
            ),
        ],
        ranges: {
          for (final message in messages)
            if (source.hidden[message.id]?.isNotEmpty == true)
              message.id: source.hidden[message.id]!,
        },
      ),
    );
    if (edited == null || !identical(session, _controller.session)) return;
    final results = {for (final result in edited) result.messageId: result};
    final removedIds = messageIds.difference(results.keys.toSet());
    final hidden = {
      for (final entry in source.hidden.entries)
        if (!messageIds.contains(entry.key)) entry.key: entry.value,
      for (final result in edited)
        if (result.ranges.isNotEmpty) result.messageId: result.ranges,
    };
    final excluded = source.excluded.difference(removedIds);
    final updated = PersonaChatImport(
      vaultId: chat.vaultId,
      personId: chat.personId,
      personaId: chat.personaId,
      importId: chat.importId,
      importedAt: chat.importedAt,
      speakers: chat.speakers,
      messages: [
        for (final message in chat.messages)
          if (!removedIds.contains(message.id))
            if (results[message.id] case final result?)
              PersonaImportMessage(
                id: message.id,
                speakerId: message.speakerId,
                text: result.text,
                sentAtLocal: message.sentAtLocal,
                system: message.system,
                quoteRanges: updatePrivateRanges(
                  message.text,
                  result.text,
                  message.quoteRanges,
                ),
              )
            else
              message,
      ],
    );
    await _controller.updateImport(updated, hidden: hidden, excluded: excluded);
  }

  Future<void> _chooseDate(
    PersonaChatSource source,
    PersonaChatImport chat,
    bool start,
  ) async {
    final session = _controller.session;
    final days =
        chat.messages.map((m) => m.sentAtLocal.substring(0, 10)).toList()
          ..sort();
    final first = DateTime.parse(
      !start && source.fromDate != null ? source.fromDate! : days.first,
    );
    final last = DateTime.parse(
      start && source.toDate != null ? source.toDate! : days.last,
    );
    final current = start ? source.fromDate : source.toDate;
    final picked = await showAppDatePickerDialog(
      context: context,
      title: start ? context.l10n.personaFromDate : context.l10n.personaToDate,
      initialDate: current == null
          ? (start ? first : last)
          : DateTime.parse(current),
      firstDate: first,
      lastDate: last,
    );
    if (!mounted ||
        picked == null ||
        !identical(session, _controller.session)) {
      return;
    }
    if (start) {
      source.fromDate = DateOnly.fromDateTime(picked).value;
    } else {
      source.toDate = DateOnly.fromDateTime(picked).value;
    }
    _controller.resetToMaterials();
  }

  Widget _confirmation() {
    final l = context.l10n;
    final preview = _controller.preview!;
    final subjectName = ref
        .read(personDetailProvider(widget.personId))
        .value
        ?.name;
    final showsSubjectName =
        subjectName?.trim().isNotEmpty == true &&
        preview.blocks.any(
          (material) =>
              material.speakerRole == PersonaSpeakerRole.personaSubject &&
              privacyTokenRanges(material.speaker ?? '').isNotEmpty,
        );
    return AppScrollbar(
      controller: _scroll,
      child: ListView(
        key: const ValueKey('persona-confirmation'),
        controller: _scroll,
        physics: appBouncingScrollPhysics,
        padding: const EdgeInsets.all(16),
        children: [
          if (preview.connection case final connection?) ...[
            AiConnectionSetupNotice(
              connection: connection,
              onOpenSettings: _controller.busy || _acting
                  ? null
                  : () => _run(_recoverAiSettings),
              padding: const EdgeInsets.only(bottom: 20),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: PageStyle.sectionGap),
              child: AiChatModelPicker.field(
                current: connection,
                enabled:
                    !_controller.busy &&
                    !_acting &&
                    ref.watch(aiEnabledProvider),
                onSelected: (option) => _run(() async {
                  await _controller.selectModel(option);
                  await _controller.prepare(l);
                }),
              ),
            ),
          ],
          if (preview.modelTarget != null)
            Padding(
              padding: const EdgeInsets.only(bottom: PageStyle.sectionGap),
              child: _CollapsibleCard(
                key: const ValueKey('persona-system-prompt'),
                title: l.personaSystemPrompt,
                text: preview.instructions,
                style: _bodyStyle,
              ),
            ),
          if (preview.requiresBatching) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l.personaBatchHint, style: _hintStyle),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: PageStyle.sectionGap),
              child: _CollapsibleCard(
                key: const ValueKey('persona-batch-system-prompt'),
                title: l.personaBatchSystemPrompt,
                text: preview.extractionInstructions,
                style: _bodyStyle,
              ),
            ),
          ],
          if (preview.updateTarget == PersonaUpdateTarget.tone &&
              preview.modelTarget == null)
            Padding(
              padding: const EdgeInsets.only(bottom: PageStyle.sectionGap),
              child: Text(
                _controller.draft!.includeCurrent[PersonaCardKind.tone] == true
                    ? l.personaToneLocalRetainedHint
                    : l.personaToneLocalNeutralHint,
                style: _hintStyle,
              ),
            ),
          ..._cardPreviews(preview, l),
          if (preview.modelTarget != null && showsSubjectName)
            Padding(
              padding: const EdgeInsets.only(bottom: PageStyle.sectionGap),
              child: Text(l.personaSpeakerNamePreviewHint, style: _hintStyle),
            ),
          if (preview.modelTarget != null)
            ..._materialPreviews(preview.blocks, subjectName: subjectName),
          if (_controller.failed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(l.personaRetryHint),
            ),
        ],
      ),
    );
  }

  Iterable<Widget> _cardPreviews(
    PersonaGenerationContext preview,
    AppLocalizations l,
  ) sync* {
    for (final kind in _cardOrder.where(
      _controller.draft!.target.kinds.contains,
    )) {
      if (_controller.draft!.includeCurrent[kind] != true ||
          _controller.record!.cards?[kind] == null) {
        continue;
      }
      final text =
          preview.baseline[kind.name] ??
          _content(preview.fallbackCards[kind]!).text;
      yield _section(
        preview.baseline.containsKey(kind.name)
            ? l.personaIncludedContentTitle(personaCardLabel(l, kind))
            : l.personaRetainedContentTitle(personaCardLabel(l, kind)),
        [
          PrivateText(
            text: text,
            ranges: privacyTokenRanges(text),
            style: _bodyStyle,
          ),
        ],
      );
    }
  }

  Iterable<Widget> _materialPreviews(
    List<PersonaMaterial> materials, {
    required String? subjectName,
  }) sync* {
    final chatsByDate = <String, List<PersonaMaterial>>{};
    for (final material in materials.where((material) => !material.isDiary)) {
      chatsByDate
          .putIfAbsent(material.date.split('T').first, () => [])
          .add(material);
    }
    final dates = chatsByDate.keys.toList()..sort();
    for (final date in dates) {
      final messages = chatsByDate[date]!.indexed.toList()
        ..sort((left, right) {
          final order = left.$2.date.compareTo(right.$2.date);
          return order == 0 ? left.$1.compareTo(right.$1) : order;
        });
      final showSource =
          messages.map((item) => item.$2.label).toSet().length > 1;
      yield _section(date.isEmpty ? context.l10n.personaChatRawLabel : date, [
        for (final item in messages)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!item.$2.isRaw)
                _chatPreviewMetadata(
                  item.$2,
                  showSource: showSource,
                  subjectName: subjectName,
                )
              else if (showSource)
                Text(item.$2.label, style: _hintStyle),
              if (!item.$2.isRaw || showSource) const SizedBox(height: 8),
              _materialText(item.$2),
            ],
          ),
      ]);
    }
    for (final material in materials.where((material) => material.isDiary)) {
      yield _section(material.label, [
        Text(material.date, style: _hintStyle),
        _materialText(material),
      ]);
    }
  }

  Widget _chatPreviewMetadata(
    PersonaMaterial material, {
    required bool showSource,
    required String? subjectName,
  }) {
    final l = context.l10n;
    final role = switch (material.speakerRole) {
      PersonaSpeakerRole.personaSubject => l.personaRoleSubject,
      PersonaSpeakerRole.user => l.personaRoleUser,
      _ => l.personaRoleOther,
    };
    final time =
        RegExp(r'T(\d{2}:\d{2})').firstMatch(material.date)?.group(1) ??
        material.date;
    final source = showSource ? '${material.label} · ' : '';
    final showsSubjectName =
        material.speakerRole == PersonaSpeakerRole.personaSubject &&
        subjectName?.trim().isNotEmpty == true &&
        privacyTokenRanges(material.speaker ?? '').isNotEmpty;
    final name = material.speakerRole == PersonaSpeakerRole.user
        ? null
        : showsSubjectName
        ? subjectName
        : material.speaker;
    final speaker = [role, name].whereType<String>().join(' · ');
    final span = TextSpan(
      children: [
        TextSpan(text: source),
        TextSpan(
          text: speaker,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        TextSpan(text: ' · $time'),
      ],
    );
    return PrivateText.rich(
      span,
      ranges: [
        ...privacyTokenRanges(span.toPlainText()),
        if (showsSubjectName)
          PrivateTextRange(
            source.length + role.length + 3,
            source.length + role.length + 3 + name!.length,
          ),
      ],
      style: _hintStyle,
    );
  }

  Widget _materialText(PersonaMaterial material) => PrivateText(
    text: material.text,
    ranges: [
      ...privacyTokenRanges(material.text),
      for (final match in personaHiddenText.allMatches(material.text))
        PrivateTextRange(match.start, match.end),
    ],
    style: _bodyStyle,
  );

  Widget _review() {
    final l = context.l10n;
    final draft = _controller.draft!;
    return AppScrollbar(
      controller: _reviewScroll,
      child: ListView(
        controller: _reviewScroll,
        physics: appBouncingScrollPhysics,
        key: const ValueKey('persona-review'),
        padding: const EdgeInsets.all(16),
        children: [
          _replyRules(),
          AppInsetPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.personaReviewHint, style: _hintStyle),
                const SizedBox(height: 8),
                Text(l.personaSaveHint, style: _hintStyle),
              ],
            ),
          ),
          const SizedBox(height: PageStyle.sectionGap),
          for (final kind in _cardOrder.where(draft.target.kinds.contains)) ...[
            _reviewCard(kind),
            const SizedBox(height: PageStyle.sectionGap),
          ],
        ],
      ),
    );
  }

  Widget _reviewCard(PersonaCardKind kind) {
    final l = context.l10n;
    final candidate = _controller.draft!.candidate![kind]!;
    final saved = _controller.record!.cards?[kind];
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSectionHeader(
                  title: personaCardLabel(l, kind),
                  description: _cardDescription(l, kind),
                  icon: _cardIcon(kind),
                ),
                const SizedBox(height: 12),
                if (_content(candidate).hasUnresolvedReferences) ...[
                  Text(l.personaUnresolvedReferenceHint, style: _hintStyle),
                  const SizedBox(height: 8),
                ],
                PersonaContentEditor(
                  key: ValueKey(
                    'persona-edit-${kind.name}-${_controller.record!.personaId}-$_editorVersion',
                  ),
                  card: candidate,
                  kind: kind,
                  names: _personNames,
                  style: _bodyStyle,
                  valid: _controller.isCandidateValid(kind),
                  onChanged: (text) => _controller.editCandidate(kind, text),
                ),
              ],
            ),
          ),
          if (saved != null) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => _showSavedCompare(kind, saved),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.compare_arrows_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l.personaCompareWithCurrent,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showSavedCompare(PersonaCardKind kind, PersonaCandidate saved) {
    final l = context.l10n;
    final session = _controller.session;
    final candidate = _controller.draft?.candidate?[kind];
    if (session == null || _backgrounded || candidate == null) {
      return Future.value();
    }
    final fontSize = _bodyStyle.fontSize ?? 16;
    return _dialog<void>(
      _SavedCompareDialog(
        title: l.personaCompare,
        cardLabel: personaCardLabel(l, kind),
        lines: organizationDiffLines(
          _content(saved).text,
          _content(candidate).text,
        ),
        style: _bodyStyle.copyWith(
          fontSize: fontSize > 16 ? 16 : fontSize,
          height: 1.4,
        ),
        closeLabel: l.commonActionClose,
        restoreLabel: l.personaRestore,
        confirmTitle: l.personaRestoreTitle,
        confirmBody: l.personaRestoreBody,
        cancelLabel: l.commonActionCancel,
        onRestore: () {
          if (identical(session, _controller.session)) {
            _restoreCard(kind, saved);
          }
        },
      ),
    );
  }

  void _restoreCard(PersonaCardKind kind, PersonaCandidate saved) {
    _controller.draft!.candidate![kind] = PersonaCandidate(
      text: saved.text,
      tokens: saved.tokens,
    );
    _controller.schedulePersist();
    setState(() => _editorVersion++);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(peopleListProvider);
    final controller = ref.watch(personaControllerProvider(widget.personId));
    final person = ref.watch(personDetailProvider(widget.personId)).value;
    final l = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final d = controller.draft;
        final disabled = _acting || controller.busy;
        final canAdvance = _canAdvance(controller, d, disabled);
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop && controller.session != null) {
              unawaited(controller.persist().catchError((Object _) {}));
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                person == null
                    ? l.personaTitle
                    : '${person.name} · ${l.personaTitle}',
              ),
              actions: [
                IconButton(
                  tooltip: d == null ? l.personaDelete : l.personaCancelUpdate,
                  color: Theme.of(context).colorScheme.error,
                  icon: Icon(d == null ? Icons.delete_outline : Icons.close),
                  onPressed:
                      disabled ||
                          controller.loading ||
                          controller.session == null
                      ? null
                      : () => _run(() async {
                          if (d != null) {
                            if (!await _confirm(
                              l.personaCancelUpdate,
                              l.personaDiscardConfirm,
                            )) {
                              return;
                            }
                            await _controller.discardUpdate();
                            if (context.mounted && _controller.record == null) {
                              context.pop();
                            }
                          } else {
                            if (!await _confirm(
                              l.personaDelete,
                              l.personaDeleteConfirm,
                            )) {
                              return;
                            }
                            await _controller.delete();
                            if (context.mounted) context.pop();
                          }
                        }),
                ),
              ],
            ),
            body: _sessionBody(
              controller: controller,
              draft: d,
              l: l,
              disabled: disabled,
              canAdvance: canAdvance,
            ),
          ),
        );
      },
    );
  }

  bool _canAdvance(
    PersonaController controller,
    PersonaDraft? draft,
    bool disabled,
  ) {
    if (disabled) return false;
    if (draft?.step != PersonaStep.review && !ref.watch(aiEnabledProvider)) {
      return false;
    }
    if (draft?.step == PersonaStep.confirmation) {
      final preview = controller.preview;
      if (preview == null) return false;
      if (preview.modelTarget != null &&
          ref.watch(aiConnectionReadyProvider(preview.connection!)).value !=
              true) {
        return false;
      }
    }
    if (draft?.step == PersonaStep.materials &&
        (!controller.hasMaterials || controller.materialsNeedReview)) {
      return false;
    }
    if (draft?.step == PersonaStep.review && !controller.canSaveCandidate) {
      return false;
    }
    return true;
  }

  Widget _sessionBody({
    required PersonaController controller,
    required PersonaDraft? draft,
    required AppLocalizations l,
    required bool disabled,
    required bool canAdvance,
  }) {
    if (_backgrounded || controller.session == null) {
      return const Center(child: Icon(Icons.lock_outline));
    }
    if (_needsAiSettings) {
      return Center(
        child: AiFeatureErrorPanel(
          message: l.aiErrorSettings,
          onOpenSettings: _acting ? null : () => _run(_recoverAiSettings),
          openSettingsLabel: l.aiOpenSettings,
        ),
      );
    }
    if (controller.loading) {
      return const AppLoadingState(layout: AppLoadingStateLayout.page);
    }
    if (controller.failed && controller.record == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.personaNeedsRecovery),
              TextButton(
                onPressed: _initialize,
                child: Text(l.commonActionConfirm),
              ),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      child: _wizardColumn(controller, draft, l, disabled, canAdvance),
    );
  }

  Widget _wizardColumn(
    PersonaController controller,
    PersonaDraft? draft,
    AppLocalizations l,
    bool disabled,
    bool canAdvance,
  ) {
    return Column(
      children: [
        if (draft != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.personaWizardStep(
                    draft.step.index + 1,
                    PersonaStep.values.length,
                    personaStepLabel(l, draft.step),
                  ),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                _stepProgress(draft.step),
              ],
            ),
          ),
        if (controller.failed)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l.personaError),
          ),
        if (controller.cleanupPending)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l.personaCleanupPending),
          ),
        Expanded(child: _wizardStep(controller, draft)),
        if (controller.busy)
          AiGenerationCard(
            title: l.personaProcessing,
            status: l.personaRequestProgress(
              controller.completedRequests,
              controller.totalRequests,
            ),
            hint: l.personaRetryHint,
            onStop: controller.stop,
          )
        else if (draft != null)
          draft.step == PersonaStep.review
              ? _reviewActions(
                  draft,
                  l,
                  disabled: disabled,
                  canSave: canAdvance,
                )
              : _stepActions(
                  draft,
                  l,
                  disabled: disabled,
                  canAdvance: canAdvance,
                ),
      ],
    );
  }

  Widget _wizardStep(PersonaController controller, PersonaDraft? draft) {
    if (draft == null) {
      return controller.record?.cards == null
          ? const SizedBox.shrink()
          : _ready();
    }
    return switch (draft.step) {
      PersonaStep.materials => _materials(),
      PersonaStep.confirmation => _confirmation(),
      PersonaStep.review => _review(),
    };
  }

  Widget _reviewActions(
    PersonaDraft draft,
    AppLocalizations l, {
    required bool disabled,
    required bool canSave,
  }) {
    final discard = !draft.manualEdit;
    final trial = OutlinedButton.icon(
      key: const ValueKey('persona-trial'),
      onPressed: disabled || !ref.watch(aiEnabledProvider)
          ? null
          : () => _run(() async {
              await _controller.persist();
              final cards = {
                ...?_controller.record!.cards?.map(
                  (kind, value) => MapEntry(kind, value as PersonaCandidate),
                ),
                ...draft.candidate!,
              };
              await _dialog<void>(
                PersonaTrialPage(
                  personId: widget.personId,
                  personaId: _controller.record!.personaId,
                  cards: cards,
                  connection: await _controller.selectedConnection(),
                ),
              );
            }),
      icon: const Icon(Icons.chat_outlined),
      label: Text(l.personaTrial),
    );
    final save = FilledButton(
      key: const ValueKey('persona-primary'),
      onPressed: canSave ? () => _run(_controller.save) : null,
      child: Text(l.personaSave),
    );
    return _wizardActionBar(
      leading: discard
          ? TextButton(
              key: const ValueKey('persona-discard-result'),
              onPressed: disabled
                  ? null
                  : () => _run(_controller.discardResult),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l.personaDiscardResult),
            )
          : null,
      actions: [trial, save],
    );
  }

  Widget _stepProgress(PersonaStep step) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final item in PersonaStep.values) ...[
          if (item.index > 0) const SizedBox(width: 6),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: item.index <= step.index
                    ? colors.primary
                    : colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const SizedBox(height: 4),
            ),
          ),
        ],
      ],
    );
  }

  /// 次要操作獨立一列，避免窄螢幕擠壓主要按鈕。
  Widget _wizardActionBar({Widget? leading, required List<Widget> actions}) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (leading != null) ...[
              Align(alignment: Alignment.centerLeft, child: leading),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepActions(
    PersonaDraft draft,
    AppLocalizations l, {
    required bool disabled,
    required bool canAdvance,
  }) {
    final advance = FilledButton(
      key: const ValueKey('persona-primary'),
      onPressed: !canAdvance
          ? null
          : () => _run(() async {
              if (draft.step == PersonaStep.materials) {
                await _controller.prepare(l);
              } else {
                unawaited(_controller.generate());
              }
            }),
      child: Text(
        draft.step == PersonaStep.materials ? l.personaNext : l.personaGenerate,
      ),
    );
    if (draft.step != PersonaStep.confirmation) {
      return _wizardActionBar(actions: [advance]);
    }
    return _wizardActionBar(
      actions: [
        OutlinedButton(
          onPressed: disabled ? null : _controller.resetToMaterials,
          child: Text(l.personaBackMaterials),
        ),
        advance,
      ],
    );
  }
}

class _SavedCompareDialog extends StatelessWidget {
  const _SavedCompareDialog({
    required this.title,
    required this.cardLabel,
    required this.lines,
    required this.style,
    required this.closeLabel,
    required this.restoreLabel,
    required this.confirmTitle,
    required this.confirmBody,
    required this.cancelLabel,
    required this.onRestore,
  });

  final String title;
  final String cardLabel;
  final List<OrganizationDiffLine> lines;
  final TextStyle style;
  final String closeLabel;
  final String restoreLabel;
  final String confirmTitle;
  final String confirmBody;
  final String cancelLabel;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return AppDialogShell(
      icon: Icon(Icons.difference_outlined, color: colors.primary),
      title: title,
      content: SizedBox(
        height: personaDialogBodyHeight(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              cardLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                  child: ColoredBox(
                    color: colors.surface,
                    child: OrganizationDiffView(
                      lines: lines,
                      textStyle: style,
                      panel: true,
                    ),
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
          child: Text(closeLabel),
        ),
        FilledButton(
          onPressed: () async {
            final bool confirmed = await showAppConfirmDialog(
              context: context,
              title: confirmTitle,
              content: Text(confirmBody),
              cancelLabel: cancelLabel,
              confirmLabel: restoreLabel,
            );
            if (!confirmed || !context.mounted) return;
            Navigator.pop(context);
            onRestore();
          },
          child: Text(restoreLabel),
        ),
      ],
    );
  }
}

class _CollapsibleCard extends StatefulWidget {
  const _CollapsibleCard({
    super.key,
    required this.title,
    required this.text,
    required this.style,
  });

  final String title;
  final String text;
  final TextStyle style;

  @override
  State<_CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<_CollapsibleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: _SavedPersonaText(text: widget.text, style: widget.style),
            ),
        ],
      ),
    );
  }
}

class _SavedPersonaText extends StatefulWidget {
  const _SavedPersonaText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_SavedPersonaText> createState() => _SavedPersonaTextState();
}

class _SavedPersonaTextState extends State<_SavedPersonaText> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppInsetPanel(
      padding: EdgeInsets.zero,
      backgroundColor: context.appColors.sectionCard,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: AiPreviewTextSection.bodyMaxHeight,
        ),
        child: AppScrollbar(
          controller: _scroll,
          track: AppScrollbarTrack.frame,
          child: ListView(
            controller: _scroll,
            shrinkWrap: true,
            primary: false,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              SelectionArea(
                child: PrivateText(
                  text: widget.text,
                  ranges: privacyTokenRanges(widget.text),
                  style: widget.style,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedPersonaActions extends StatelessWidget {
  const _SavedPersonaActions({
    required this.editLabel,
    required this.updateLabel,
    required this.onEdit,
    required this.onUpdate,
  });

  final String editLabel;
  final String updateLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    Widget action(IconData icon, String label, VoidCallback? onPressed) {
      final Color actionColor = onPressed == null
          ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
          : color;
      return InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: actionColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: actionColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: action(Icons.edit_outlined, editLabel, onEdit)),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: theme.colorScheme.outlineVariant,
          ),
          Expanded(
            child: action(Icons.auto_awesome_outlined, updateLabel, onUpdate),
          ),
        ],
      ),
    );
  }
}
