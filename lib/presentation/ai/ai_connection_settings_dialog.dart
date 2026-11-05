import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/ai/ai_prompts.dart';
import 'package:quill_diary/application/errors/ai_error_text.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_labels.dart';
import 'package:quill_diary/presentation/ai/ai_model_thinking_dialog.dart';
import 'package:quill_diary/presentation/ai/ai_prompt_dialog.dart';
import 'package:quill_diary/presentation/ai/ai_settings_theme.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_menu_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_option_field.dart';

class AiConnectionSettingsResult {
  const AiConnectionSettingsResult({this.chatConnection});
  final AiConnectionConfig? chatConnection;
}

Future<AiConnectionSettingsResult?> showAiConnectionSettingsDialog(
  BuildContext context, {
  AiConnectionConfig? initialConnection,
  bool? initialHidePersonNames,
}) async => await showAppDialog<AiConnectionSettingsResult>(
  context: context,
  builder: (_) => AiConnectionSettingsDialog(
    initialConnection: initialConnection,
    initialHidePersonNames: initialHidePersonNames,
  ),
);

class AiConnectionSettingsDialog extends ConsumerStatefulWidget {
  const AiConnectionSettingsDialog({
    super.key,
    this.initialConnection,
    this.initialHidePersonNames,
  });
  final AiConnectionConfig? initialConnection;
  final bool? initialHidePersonNames;
  @override
  ConsumerState<AiConnectionSettingsDialog> createState() =>
      _AiConnectionSettingsDialogState();
}

class _AiCredentialDraft {
  const _AiCredentialDraft(this.connectionConfig, this.apiKey);
  final AiConnectionConfig connectionConfig;
  final String apiKey;
}

class _AiConnectionDraft {
  _AiConnectionDraft(this.config)
    : apiKey = TextEditingController(),
      modelAdd = TextEditingController(),
      url = TextEditingController(text: config.baseUrl),
      workspace = TextEditingController(text: config.workspaceId),
      name = TextEditingController(text: config.displayName);
  AiConnectionConfig config;
  final TextEditingController apiKey, modelAdd, url, workspace, name;
  final nameFieldKey = GlobalKey();
  bool keyLoaded = true;
  int keyVersion = 0;
  AiConnectionConfig get edited => normalizeModelCatalog(
    config.copyWith(
      baseUrl: url.text.trim(),
      workspaceId: workspace.text.trim(),
      displayName: name.text.trim(),
    ),
  );
  void dispose() {
    for (final controller in [apiKey, modelAdd, url, workspace, name]) {
      controller.dispose();
    }
  }
}

class _AiConnectionSettingsDialogState
    extends ConsumerState<AiConnectionSettingsDialog>
    with WidgetsBindingObserver {
  final _drafts = <String, _AiConnectionDraft>{};
  final _credentials = <String, _AiCredentialDraft>{};
  final _credentialsPendingDeletion = <String, _AiCredentialDraft>{};
  final _removedConnectionIds = <String>{};
  String _selectedConnectionId = 'openai';
  String? _expandedCustomId;
  String? _invalidNameId;
  _AiConnectionDraft? _snapshotDraft;
  bool _initialTargetMatches = false;
  bool _settingsLoaded = false;
  String? _testingConnectionId;
  bool get _isTestingConnection => _testingConnectionId != null;
  int _connectionTestVersion = 0;
  String? _conversationOverride, _generationOverride;
  String? _organizationConversationOverride, _organizationGenerationOverride;
  bool _hidePersonNames = true;
  bool _isLoadingSettings = true;
  bool _isSavingSettings = false;
  bool _isBackgrounded = false;
  bool _settingsScrollLocked = false;
  final _settingsScroll = ScrollController();
  List<({String connectionId, String model})> _modelOrder = const [];
  bool get _isBusy => _isTestingConnection || _isSavingSettings;
  AiClient? _connectionTestClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(appSessionProvider, (_, next) {
      if (next.status == AppLockStatus.locked ||
          next.status == AppLockStatus.recoveryRequired) {
        _cancelConnectionTest();
        if (mounted) {
          final route = ModalRoute.of(context);
          Navigator.of(context).popUntil((current) => current == route);
          Navigator.of(context).pop();
        }
      }
    });
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _cancelConnectionTest();
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (mounted) {
      setState(() => _isBackgrounded = state != AppLifecycleState.resumed);
    }
  }

  Future<void> _load() async {
    try {
      final session = ref.read(appSessionProvider).session;
      if (session == null) throw StateError('尚未解鎖');
      final store = ref.read(aiSettingsStoreProvider);
      final stored = await store.read(session);
      if (!mounted) return;
      var index = 1;
      for (var config in stored.connection.orderedConnections) {
        if (config.provider == AiProvider.custom &&
            config.displayName.isEmpty) {
          config = config.copyWith(
            displayName: context.l10n.aiCustomConnectionName(index),
          );
        }
        if (config.provider == AiProvider.custom) index++;
        final draft = _AiConnectionDraft(config);
        _drafts[config.connectionId] = draft;
        final key = await store.readApiKey(config);
        if (!mounted) return;
        draft.apiKey.text = key;
        _credentials[config.credentialId] = _AiCredentialDraft(
          config,
          draft.apiKey.text,
        );
      }
      _selectedConnectionId = stored.connection.activeConnectionId;
      final initial = widget.initialConnection;
      if (initial != null) {
        final draft = _drafts[initial.connectionId];
        _initialTargetMatches =
            draft != null &&
            sameAiTarget(draft.config.copyWith(model: initial.model), initial);
        if (!_initialTargetMatches &&
            (draft == null ||
                draft.config.credentialId != initial.credentialId)) {
          final snapshot = _snapshotDraft = _AiConnectionDraft(initial);
          final key = await store.readApiKey(initial);
          if (!mounted) return;
          snapshot.apiKey.text = key;
          _credentials[initial.credentialId] = _AiCredentialDraft(
            initial,
            snapshot.apiKey.text,
          );
        }
      }
      _expandedCustomId = _drafts.values
          .where((d) => d.config.provider == AiProvider.custom)
          .firstOrNull
          ?.config
          .connectionId;
      _conversationOverride = stored.chatDiaryPrompts.conversationOverride;
      _generationOverride = stored.chatDiaryPrompts.generationOverride;
      _organizationConversationOverride =
          stored.organizationPrompts.conversationOverride;
      _organizationGenerationOverride =
          stored.organizationPrompts.generationOverride;
      _hidePersonNames =
          widget.initialHidePersonNames ?? stored.hidePersonNames;
      _refreshModelOrder();
      setState(() {
        _isLoadingSettings = false;
        _settingsLoaded = true;
      });
    } on Object {
      if (mounted) {
        setState(() => _isLoadingSettings = false);
        _showError(AiErrorCode.storage);
      }
    }
  }

  AiConnectionConfig _edited(String id) => _drafts[id]!.edited;

  void _replaceConnection(String id, AiConnectionConfig config) {
    _drafts[id]!.config = config;
  }

  void _capture(String id) {
    final draft = _drafts[id]!;
    final config = draft.edited;
    draft.config = config;
    if (!draft.keyLoaded) return;
    _credentials[config.credentialId] = _AiCredentialDraft(
      config,
      draft.apiKey.text,
    );
  }

  void _addModel(String id) {
    final draft = _drafts[id]!;
    if (draft.modelAdd.text.trim().isEmpty) return;
    setState(() {
      _replaceConnection(id, addModel(_edited(id), draft.modelAdd.text));
      _refreshModelOrder();
      draft.modelAdd.clear();
    });
  }

  Future<void> _urlChanged(String id) async {
    final draft = _drafts[id]!;
    final previous = draft.config;
    if (draft.keyLoaded) {
      _credentials[previous.credentialId] = _AiCredentialDraft(
        previous,
        draft.apiKey.text,
      );
    }
    final config = draft.edited;
    draft.config = config;
    final version = ++draft.keyVersion;
    final known = _credentials[config.credentialId];
    setState(() {
      draft.apiKey.text = known?.apiKey ?? '';
      draft.keyLoaded = known != null;
    });
    if (known != null) return;
    try {
      final key = await ref.read(aiSettingsStoreProvider).readApiKey(config);
      if (!mounted || draft.keyVersion != version) return;
      setState(() {
        draft.apiKey.text = key;
        draft.keyLoaded = true;
      });
      _credentials[config.credentialId] = _AiCredentialDraft(config, key);
    } on Object {
      if (mounted && draft.keyVersion == version) {
        _showError(AiErrorCode.storage);
      }
    }
  }

  void _addCustomConnection() {
    final names = _drafts.values.map((d) => normalizeText(d.name.text)).toSet();
    var number = 1;
    while (names.contains(
      normalizeText(context.l10n.aiCustomConnectionName(number)),
    )) {
      number++;
    }
    final id = generateAiConnectionId();
    setState(() {
      _drafts[id] = _AiConnectionDraft(
        AiConnectionConfig(
          provider: AiProvider.custom,
          customConnectionId: id,
          displayName: context.l10n.aiCustomConnectionName(number),
        ),
      );
      _expandedCustomId = id;
      _refreshModelOrder();
    });
  }

  Future<void> _deleteCustomConnection(String id) async {
    final draft = _drafts[id];
    if (_isBusy || draft == null) return;
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    final confirmed = await _withoutOuterScroll(
      () => showAppConfirmDialog(
        context: context,
        title: l10n.aiConnectionDeleteConfirmTitle,
        content: Text(
          l10n.aiConnectionDeleteConfirmBody(draft.name.text.trim()),
        ),
        cancelLabel: l10n.commonActionCancel,
        confirmLabel: l10n.commonActionDelete,
        confirmStyle: AppConfirmStyle.destructive,
      ),
    );
    if (!mounted || confirmed != true || _drafts[id] != draft) return;
    _capture(id);
    for (final credential in _credentials.values) {
      if (credential.connectionConfig.connectionId == id) {
        _credentialsPendingDeletion[credential.connectionConfig.credentialId] =
            credential;
      }
    }
    setState(() {
      draft.keyVersion++;
      _drafts.remove(id);
      _removedConnectionIds.add(id);
      _credentials.removeWhere(
        (_, value) => value.connectionConfig.connectionId == id,
      );
      if (_expandedCustomId == id) _expandedCustomId = null;
      if (_invalidNameId == id) _invalidNameId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
  }

  Future<void> _editThinking(String id, String model) async {
    final result = await _withoutOuterScroll(
      () => showAiModelThinkingDialog(context, _edited(id), model),
    );
    if (!mounted ||
        result == null ||
        _drafts[id]?.edited.catalog.contains(model) != true) {
      return;
    }
    setState(() {
      final config = _edited(id);
      final overrides = {...config.thinkingOverrides};
      if (result.override == null) {
        overrides.remove(model);
      } else {
        overrides[model] = result.override!;
      }
      var next = config.copyWith(thinkingOverrides: overrides);
      final levels = {...next.thinkingLevels};
      if (!thinkingChoicesFor(next, model).contains(levels[model])) {
        levels.remove(model);
      }
      next = next.copyWith(thinkingLevels: levels);
      _replaceConnection(id, next);
    });
  }

  void _showError(AiErrorCode code, {int? status}) {
    final message = aiErrorText(context.l10n, code);
    showAppFeedbackToast(
      context,
      status == null
          ? message
          : context.l10n.aiConnectionHttpFailure(status, message),
      tone: AppFeedbackTone.error,
    );
  }

  void _cancelConnectionTest() {
    _connectionTestVersion++;
    _connectionTestClient?.close();
    _connectionTestClient = null;
    _testingConnectionId = null;
  }

  bool _connectionIsCurrent(int version) =>
      !_isBackgrounded &&
      version == _connectionTestVersion &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _testConnection(String id) async {
    if (_isBusy || !_drafts[id]!.keyLoaded) return;
    final version = ++_connectionTestVersion;
    FocusScope.of(context).unfocus();
    setState(() => _testingConnectionId = id);
    AiClient? client;
    try {
      _capture(id);
      final AiConnectionConfig connectionConfig = _edited(id);
      validateAiEndpoint(connectionConfig);
      final String apiKey = _drafts[id]!.apiKey.text.trim();
      if (!connectionConfig.isConfigured ||
          (connectionConfig.provider.requiresApiKey && apiKey.isEmpty)) {
        throw const AiFailure(AiErrorCode.configuration);
      }
      client = ref.read(aiClientFactoryProvider)(connectionConfig, apiKey);
      _connectionTestClient = client;
      await client.testConnection();
      if (mounted && _connectionIsCurrent(version)) {
        showAppFeedbackToast(
          context,
          context.l10n.aiConnectionSuccess,
          tone: AppFeedbackTone.success,
        );
      }
    } on AiFailure catch (error) {
      if (mounted && _connectionIsCurrent(version)) {
        _showError(error.code, status: error.status);
      }
    } on FormatException {
      if (mounted && _connectionIsCurrent(version)) {
        _showError(AiErrorCode.response);
      }
    } on Object {
      if (mounted && _connectionIsCurrent(version)) {
        showAppFeedbackToast(
          context,
          context.l10n.aiErrorUnexpected,
          tone: AppFeedbackTone.error,
        );
      }
    } finally {
      client?.close();
      if (_connectionTestClient == client) {
        _connectionTestClient = null;
      }
      if (mounted && _connectionIsCurrent(version)) {
        setState(() => _testingConnectionId = null);
      }
    }
  }

  Future<T?> _withoutOuterScroll<T>(Future<T?> Function() open) async {
    final double saved = _settingsScroll.hasClients
        ? _settingsScroll.offset
        : 0;
    final wasLocked = _settingsScrollLocked;
    setState(() => _settingsScrollLocked = true);
    _holdSettingsScroll(saved);
    try {
      return await open();
    } finally {
      if (mounted) {
        setState(() => _settingsScrollLocked = wasLocked);
        _holdSettingsScroll(saved);
      }
    }
  }

  void _holdSettingsScroll(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_settingsScroll.hasClients) return;
      final double max = _settingsScroll.position.maxScrollExtent;
      if (!max.isFinite) return;
      _settingsScroll.jumpTo(offset.clamp(0, max));
    });
  }

  Future<void> _editPrompt({
    required String? customText,
    required String Function(AppLocalizations l10n) title,
    required String Function(AppLocalizations l10n) help,
    required String Function(AppLanguage language) defaultPrompt,
    required Key fieldKey,
    required void Function(String? customText) apply,
  }) async {
    final result = await _withoutOuterScroll(
      () => showAiPromptDialog(
        context,
        title: title,
        help: help,
        defaultPrompt: defaultPrompt,
        fieldKey: fieldKey,
        customText: customText,
      ),
    );
    if (mounted && result != null) setState(() => apply(result.customText));
  }

  AiConnectionSettings _settings() => AiConnectionSettings(
    activeConnectionId: _selectedConnectionId,
    connections: {for (final id in _drafts.keys) id: _edited(id)},
  );

  List<ChatModelOption> _availableModels() => chatModelMenu(
    settings: _settings(),
    chatConfig: const AiConnectionConfig(provider: AiProvider.custom),
    hasApiKey: (config) =>
        _drafts[config.connectionId]?.apiKey.text.trim().isNotEmpty ?? false,
  ).models;

  bool _hasSelectableChatModel() => _availableModels().isNotEmpty;

  Widget _settingsIntro(AppLocalizations l10n) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.aiSettingsLead, style: text.bodyMedium),
        const SizedBox(height: 8),
        _settingsNote(Icons.key_outlined, l10n.aiSettingsKeyNote),
        _settingsNote(Icons.lock_outline, l10n.aiSettingsBackupNote),
        _settingsNote(Icons.send_outlined, l10n.aiSettingsSendNote),
        if (!_hasSelectableChatModel())
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.aiSettingsNeedConnection,
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _settingsNote(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_settingsLoaded) return;
    final available = _availableModels();
    if (available.isEmpty &&
        widget.initialConnection == null &&
        _removedConnectionIds.isEmpty) {
      setState(() {});
      return;
    }
    final names = <String>{};
    for (final draft in _drafts.values) {
      if (draft.config.provider != AiProvider.custom) {
        continue;
      }
      final name = normalizeText(draft.name.text);
      if (name.isEmpty || !names.add(name)) {
        setState(() {
          _expandedCustomId = draft.config.connectionId;
          _invalidNameId = draft.config.connectionId;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final fieldContext = draft.nameFieldKey.currentContext;
          if (mounted && fieldContext != null) {
            Scrollable.ensureVisible(fieldContext, alignment: 0.5);
          }
        });
        return;
      }
    }
    setState(() => _isSavingSettings = true);
    try {
      for (final id in _drafts.keys) {
        _capture(id);
        final config = _edited(id);
        if (config.effectiveBaseUrl.isNotEmpty) {
          validateAiEndpoint(config);
        }
      }
      final snapshot = _snapshotDraft;
      if (snapshot != null) {
        final config = snapshot.edited;
        _credentials[config.credentialId] = _AiCredentialDraft(
          config,
          snapshot.apiKey.text,
        );
      }
      if (!available.any((m) => m.connectionId == _selectedConnectionId)) {
        if (available.isNotEmpty) {
          _selectedConnectionId = available.first.connectionId;
        } else if (!_drafts.containsKey(_selectedConnectionId)) {
          _selectedConnectionId = 'openai';
        }
      }
      final store = ref.read(aiSettingsStoreProvider);
      final session = ref.read(appSessionProvider).session;
      if (session == null) throw StateError('尚未解鎖');
      for (final credential in _credentials.values) {
        await store.saveApiKey(credential.connectionConfig, credential.apiKey);
      }
      await store.save(
        session,
        AiStoredSettings(
          connection: _settings(),
          hidePersonNames: _hidePersonNames,
          chatDiaryPrompts: AiPromptOverrides(
            conversationOverride: _conversationOverride,
            generationOverride: _generationOverride,
          ),
          organizationPrompts: AiPromptOverrides(
            conversationOverride: _organizationConversationOverride,
            generationOverride: _organizationGenerationOverride,
          ),
        ),
      );
      for (final credential in _credentialsPendingDeletion.values) {
        await store.saveApiKey(credential.connectionConfig, '');
      }
      _credentialsPendingDeletion.clear();
      if (!mounted) return;
      final initial = widget.initialConnection;
      final current = initial == null
          ? null
          : _drafts[initial.connectionId]?.edited;
      final chatConnection = initial == null
          ? null
          : _initialTargetMatches &&
                current != null &&
                current.catalog.contains(initial.model)
          ? current.copyWith(model: initial.model)
          : initial;
      Navigator.pop(
        context,
        AiConnectionSettingsResult(chatConnection: chatConnection),
      );
    } on AiFailure catch (error) {
      if (mounted) _showError(error.code);
    } on FormatException {
      if (mounted) _showError(AiErrorCode.configuration);
    } on Object {
      if (mounted) _showError(AiErrorCode.storage);
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  Widget _promptTile({
    required String title,
    required String? custom,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(icon, size: 22),
      minLeadingWidth: 22,
      horizontalTitleGap: 12,
      titleTextStyle: Theme.of(context).textTheme.bodyMedium,
      subtitleTextStyle: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(
        custom == null ? l10n.aiPromptBuiltIn : l10n.aiPromptCustom,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _isBusy ? null : onTap,
    );
  }

  Widget _promptGroup(List<Widget> tiles) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < tiles.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 12, endIndent: 12),
            tiles[index],
          ],
        ],
      ),
    );
  }

  List<_AiModelEntry> _modelRows() {
    final List<_AiModelEntry> enabled = [];
    final List<_AiModelEntry> disabled = [];
    for (final draft in _drafts.values) {
      final config = draft.edited;
      final provider = config.provider;
      for (final String model in config.catalog) {
        final _AiModelEntry row = (
          provider: provider,
          model: model,
          config: config,
        );
        if (config.enabledModels.contains(model)) {
          enabled.add(row);
        } else {
          disabled.add(row);
        }
      }
    }
    return [...enabled, ...disabled];
  }

  void _refreshModelOrder() {
    _modelOrder = [
      for (final _AiModelEntry row in _modelRows())
        (connectionId: row.config.connectionId, model: row.model),
    ];
  }

  List<_AiModelEntry> _stableModelRows() {
    final List<_AiModelEntry> current = _modelRows();
    final Map<String, _AiModelEntry> byId = {
      for (final _AiModelEntry row in current)
        '${row.config.connectionId}\u0000${row.model}': row,
    };
    final List<_AiModelEntry> ordered = [];
    final Set<String> seen = {};
    for (final ({String connectionId, String model}) item in _modelOrder) {
      final String id = '${item.connectionId}\u0000${item.model}';
      final _AiModelEntry? row = byId[id];
      if (row == null) continue;
      ordered.add(row);
      seen.add(id);
    }
    for (final _AiModelEntry row in current) {
      final String id = '${row.config.connectionId}\u0000${row.model}';
      if (seen.add(id)) ordered.add(row);
    }
    return ordered;
  }

  void _setListedModelEnabled(
    String id,
    String model, {
    required bool enabled,
  }) {
    setState(() {
      _replaceConnection(
        id,
        setModelEnabled(_edited(id), model, enabled: enabled),
      );
    });
  }

  void _setThinkingLevel(String id, String model, AiThinkingLevel level) {
    setState(() {
      _replaceConnection(id, setThinkingLevel(_edited(id), model, level));
    });
  }

  void _removeListedModel(String id, String model) {
    setState(() {
      _replaceConnection(id, removeAddedModel(_edited(id), model));
    });
  }

  Future<void> _openModelCatalog() {
    return _withoutOuterScroll(
      () => showAppDialog<void>(
        context: context,
        builder: (context) => _AiModelCatalogDialog(
          key: const ValueKey('ai-model-catalog-dialog'),
          rows: _modelRows,
          isBusy: () => _isBusy,
          onEnabled: _setListedModelEnabled,
          onThinking: _setThinkingLevel,
          onRemove: _removeListedModel,
          onEditThinking: _editThinking,
        ),
      ),
    );
  }

  Widget _modelCatalog(AppLocalizations l10n) {
    const int previewCount = 10;
    final List<_AiModelEntry> rows = _stableModelRows();
    final List<_AiModelEntry> visible = rows.length > previewCount
        ? rows.sublist(0, previewCount)
        : rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            l10n.aiModelsHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0) const SizedBox(height: 6),
          _AiModelTile(
            entry: visible[index],
            busy: _isBusy,
            onEnabled: _setListedModelEnabled,
            onThinking: _setThinkingLevel,
            onRemove: _removeListedModel,
            onEditThinking: _editThinking,
          ),
        ],
        if (rows.length > previewCount)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: OutlinedButton.icon(
              key: const ValueKey('ai-model-show-more'),
              onPressed: _isBusy ? null : _openModelCatalog,
              icon: const Icon(Icons.tune, size: 18),
              label: Text(l10n.aiModelShowMore),
            ),
          ),
      ],
    );
  }

  Widget _connectionSection(AppLocalizations l10n, String id) {
    final draft = _drafts[id]!;
    final config = draft.edited;
    final provider = config.provider;
    final custom = provider == AiProvider.custom;
    final query = draft.modelAdd.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!custom)
          Text(
            aiProviderLabel(l10n, provider),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        if (provider == AiProvider.gemini)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.aiGeminiPolicyNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (custom) ...[
          SizedBox(
            key: draft.nameFieldKey,
            child: TextField(
              key: ValueKey('ai-connection-name-$id'),
              controller: draft.name,
              enabled: !_isBusy,
              decoration: InputDecoration(
                labelText: l10n.aiConnectionName,
                errorText: _invalidNameId == id
                    ? l10n.aiConnectionNameInvalid
                    : null,
                errorMaxLines: 4,
              ),
              onChanged: (_) => setState(() => _invalidNameId = null),
            ),
          ),
          const SizedBox(height: 10),
          AppOptionField<AiApiProtocol>(
            key: ValueKey(
              id == 'custom' ? 'ai-protocol-field' : 'ai-protocol-field-$id',
            ),
            label: l10n.aiProtocol,
            value: config.customProtocol,
            options: [
              for (final protocol in AiApiProtocol.values)
                (protocol, aiProtocolLabel(protocol)),
            ],
            onChanged: _isBusy
                ? null
                : (value) => setState(
                    () => draft.config = draft.config.copyWith(
                      customProtocol: value,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: ValueKey('ai-connection-url-$id'),
            controller: draft.url,
            enabled: !_isBusy,
            keyboardType: TextInputType.url,
            onChanged: (_) => _urlChanged(id),
            decoration: InputDecoration(
              labelText: l10n.aiServerUrl,
              hintText: config.protocol == AiApiProtocol.ollamaChat
                  ? 'http://192.168.1.100:11434'
                  : 'https://example.com/v1',
            ),
          ),
          if (Uri.tryParse(config.effectiveBaseUrl)?.scheme == 'http')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.aiHttpNotice,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
        const SizedBox(height: 10),
        TextField(
          key: ValueKey('ai-api-key-$id'),
          controller: draft.apiKey,
          enabled: !_isBusy && draft.keyLoaded,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) {
            draft.keyVersion++;
            draft.keyLoaded = true;
            _capture(id);
            setState(() {});
          },
          decoration: InputDecoration(labelText: l10n.aiApiKey),
        ),
        if (provider == AiProvider.claude ||
            (custom && config.protocol == AiApiProtocol.claudeMessages)) ...[
          const SizedBox(height: 10),
          TextField(
            controller: draft.workspace,
            enabled: !_isBusy,
            onChanged: (_) => _capture(id),
            decoration: InputDecoration(labelText: l10n.aiWorkspace),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: ValueKey('ai-model-add-field-$id'),
          controller: draft.modelAdd,
          enabled: !_isBusy,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _addModel(id),
          decoration: InputDecoration(
            hintText: l10n.aiModelSearch,
            suffixIcon: IconButton(
              key: ValueKey('ai-model-add-$id'),
              tooltip: query.isEmpty
                  ? l10n.aiModelSearch
                  : l10n.aiModelAdd(query),
              onPressed: _isBusy || query.isEmpty ? null : () => _addModel(id),
              icon: const Icon(Icons.add),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OverflowBar(
          alignment: MainAxisAlignment.spaceBetween,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: 8,
          overflowSpacing: 4,
          children: [
            AppActionButton(
              key: ValueKey('ai-test-$id'),
              label: l10n.aiTestConnection,
              icon: Icons.wifi_tethering,
              appearance: AppActionButtonAppearance.outlined,
              loading: _testingConnectionId == id,
              onPressed: _isBusy ? null : () => _testConnection(id),
            ),
            if (custom)
              TextButton.icon(
                key: ValueKey('ai-connection-delete-$id'),
                onPressed: _isBusy ? null : () => _deleteCustomConnection(id),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.aiConnectionDelete),
              ),
          ],
        ),
      ],
    );
  }

  Widget _customConnectionCard(
    AppLocalizations l10n,
    _AiConnectionDraft draft,
  ) {
    final config = draft.edited;
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return ExpansionTile(
      key: ValueKey(
        'ai-connection-${config.connectionId}-${_expandedCustomId == config.connectionId}',
      ),
      shape: shape,
      collapsedShape: shape,
      clipBehavior: Clip.none,
      backgroundColor: colors.surfaceContainer,
      collapsedBackgroundColor: colors.surfaceContainer,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      leading: const Icon(Icons.dns_outlined, size: 22),
      initiallyExpanded: _expandedCustomId == config.connectionId,
      title: Text(
        config.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        config.effectiveBaseUrl.isEmpty
            ? l10n.aiConnectionNotConfigured
            : config.effectiveBaseUrl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onExpansionChanged: (expanded) => setState(
        () => _expandedCustomId = expanded ? config.connectionId : null,
      ),
      children: [_connectionSection(l10n, config.connectionId)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_isBackgrounded) {
      return AppDialogShell(
        title: l10n.aiSettings,
        content: Center(
          child: Semantics(
            label: l10n.aiContentHidden,
            child: const Icon(Icons.lock_outline),
          ),
        ),
      );
    }
    final height = (MediaQuery.sizeOf(context).height - 200).clamp(
      140.0,
      640.0,
    );
    final Widget dialog = AiSettingsTheme(
      child: AppDialogShell(
        title: l10n.aiSettings,
        content: SizedBox(
          width: 560,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height),
            child: _isLoadingSettings
                ? const Center(child: CircularProgressIndicator())
                : !_settingsLoaded
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    key: const ValueKey('ai-settings-scroll'),
                    controller: _settingsScroll,
                    physics: _settingsScrollLocked
                        ? const NeverScrollableScrollPhysics()
                        : const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _settingsIntro(l10n),
                        const SizedBox(height: 12),
                        _hidePeopleCard(l10n),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: l10n.chatDiaryTitle,
                          children: [
                            _promptGroup([
                              _promptTile(
                                title: l10n.chatDiaryConversationPrompt,
                                custom: _conversationOverride,
                                icon: Icons.forum_outlined,
                                onTap: () => _editPrompt(
                                  customText: _conversationOverride,
                                  title: (l10n) =>
                                      l10n.chatDiaryConversationPrompt,
                                  help: (l10n) => l10n.chatDiaryPromptHelp,
                                  defaultPrompt: (language) =>
                                      resolveChatDiaryPrompt(
                                        ChatDiaryPromptPurpose.conversation,
                                        language,
                                        const AiPromptOverrides(),
                                      ),
                                  fieldKey: const ValueKey(
                                    ChatDiaryPromptPurpose.conversation,
                                  ),
                                  apply: (value) =>
                                      _conversationOverride = value,
                                ),
                              ),
                              _promptTile(
                                title: l10n.chatDiaryGenerationPrompt,
                                custom: _generationOverride,
                                icon: Icons.article_outlined,
                                onTap: () => _editPrompt(
                                  customText: _generationOverride,
                                  title: (l10n) =>
                                      l10n.chatDiaryGenerationPrompt,
                                  help: (l10n) => l10n.chatDiaryPromptHelp,
                                  defaultPrompt: (language) =>
                                      resolveChatDiaryPrompt(
                                        ChatDiaryPromptPurpose.generation,
                                        language,
                                        const AiPromptOverrides(),
                                      ),
                                  fieldKey: const ValueKey(
                                    ChatDiaryPromptPurpose.generation,
                                  ),
                                  apply: (value) => _generationOverride = value,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: l10n.organizationTitle,
                          children: [
                            _promptGroup([
                              _promptTile(
                                title: l10n.organizationConversationPromptLabel,
                                custom: _organizationConversationOverride,
                                icon: Icons.forum_outlined,
                                onTap: () => _editPrompt(
                                  customText: _organizationConversationOverride,
                                  title: (l10n) =>
                                      l10n.organizationConversationPromptLabel,
                                  help: (l10n) => l10n.organizationPromptHelp,
                                  defaultPrompt: (language) =>
                                      resolveDiaryOrganizationPrompt(
                                        generate: false,
                                        language: language,
                                        settings: const AiPromptOverrides(),
                                      ),
                                  fieldKey: const ValueKey(
                                    'organization-conversation-prompt',
                                  ),
                                  apply: (value) =>
                                      _organizationConversationOverride = value,
                                ),
                              ),
                              _promptTile(
                                title: l10n.organizationGenerationPromptLabel,
                                custom: _organizationGenerationOverride,
                                icon: Icons.edit_note_outlined,
                                onTap: () => _editPrompt(
                                  customText: _organizationGenerationOverride,
                                  title: (l10n) =>
                                      l10n.organizationGenerationPromptLabel,
                                  help: (l10n) => l10n.organizationPromptHelp,
                                  defaultPrompt: (language) =>
                                      resolveDiaryOrganizationPrompt(
                                        generate: true,
                                        language: language,
                                        settings: const AiPromptOverrides(),
                                      ),
                                  fieldKey: const ValueKey(
                                    'organization-generation-prompt',
                                  ),
                                  apply: (value) =>
                                      _organizationGenerationOverride = value,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: l10n.aiModel,
                          children: [_modelCatalog(l10n)],
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: l10n.aiApiSection,
                          children: [
                            for (final provider in aiCatalogProviders)
                              if (provider != AiProvider.custom) ...[
                                if (provider != AiProvider.openai)
                                  const Divider(height: 28),
                                _connectionSection(l10n, provider.name),
                              ],
                            if (_snapshotDraft case final snapshot?) ...[
                              const Divider(height: 28),
                              Text(l10n.aiCurrentChatConnection),
                              Text(snapshot.config.effectiveBaseUrl),
                              TextField(
                                controller: snapshot.apiKey,
                                enabled: !_isBusy,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: l10n.aiApiKey,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: l10n.aiProviderCustom,
                          children: [
                            for (final draft in _drafts.values)
                              if (draft.config.provider == AiProvider.custom)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _customConnectionCard(l10n, draft),
                                ),
                            OutlinedButton.icon(
                              key: const ValueKey('ai-add-connection'),
                              onPressed: _isBusy ? null : _addCustomConnection,
                              icon: const Icon(Icons.add),
                              label: Text(l10n.aiConnectionAdd),
                            ),
                          ],
                        ),
                        if (_isBusy && !_isTestingConnection)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isBusy ? null : () => Navigator.pop(context),
            child: Text(l10n.commonActionCancel),
          ),
          FilledButton(
            onPressed:
                !_settingsLoaded ||
                    _isBusy ||
                    _drafts.values.any((d) => !d.keyLoaded)
                ? null
                : _save,
            child: Text(l10n.aiSaveSettings),
          ),
        ],
      ),
    );
    if (!_settingsScrollLocked) return dialog;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
      child: dialog,
    );
  }

  Widget _hidePeopleCard(AppLocalizations l10n) {
    final Color hintColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.person_off_outlined, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.chatDiaryHidePeople,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Switch(
                  value: _hidePersonNames,
                  onChanged: _isBusy
                      ? null
                      : (value) => setState(() => _hidePersonNames = value),
                ),
              ],
            ),
            Text(
              l10n.chatDiaryHidePeopleHint,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelConnectionTest();
    _credentials.clear();
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    _snapshotDraft?.dispose();
    _settingsScroll.dispose();
    super.dispose();
  }
}

typedef _AiModelEntry = ({
  AiProvider provider,
  String model,
  AiConnectionConfig config,
});

class _AiModelTile extends StatelessWidget {
  const _AiModelTile({
    required this.entry,
    required this.busy,
    required this.onEnabled,
    required this.onThinking,
    required this.onRemove,
    required this.onEditThinking,
    this.showProvider = true,
  });

  final _AiModelEntry entry;
  final bool busy;
  final bool showProvider;
  final void Function(String id, String model, {required bool enabled})
  onEnabled;
  final void Function(String connectionId, String model, AiThinkingLevel level)
  onThinking;
  final void Function(String connectionId, String model) onRemove;
  final Future<void> Function(String connectionId, String model) onEditThinking;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final enabled = entry.config.enabledModels.contains(entry.model);
    final bool removable = !entry.config.isBuiltinModel(entry.model);
    final choices = thinkingChoicesFor(entry.config, entry.model);
    final details = <Widget>[
      if (showProvider)
        Text(
          aiConnectionLabel(l10n, entry.config),
          style: text.labelMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      if (choices.isNotEmpty || removable)
        _AiThinkingMenu(
          providerName: entry.config.connectionId,
          onConfigure: removable
              ? () => onEditThinking(entry.config.connectionId, entry.model)
              : null,
          omitted:
              entry.config.thinkingOverrides[entry.model]?.levels.isEmpty ==
              true,
          model: entry.model,
          level: resolvedThinkingLevel(entry.config, entry.model),
          choices: choices,
          enabled: !busy,
          onSelected: (AiThinkingLevel level) =>
              onThinking(entry.config.connectionId, entry.model, level),
        ),
    ];
    return Material(
      key: ValueKey('ai-model-${entry.config.connectionId}-${entry.model}'),
      color: Theme.of(context).brightness == Brightness.dark
          ? (enabled ? colors.surfaceContainerHigh : colors.surfaceContainer)
          : enabled
          ? Color.alphaBlend(
              colors.primary.withValues(alpha: 0.05),
              colors.surfaceContainerLowest,
            )
          : colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? (enabled
                    ? Theme.of(context)
                          .extension<AppColors>()!
                          .entrySelectedBorder
                    : colors.outlineVariant)
              : enabled
              ? colors.primary.withValues(alpha: 0.24)
              : colors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: entry.model,
                    child: Text(
                      entry.model,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: details,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (removable)
              IconButton(
                key: ValueKey(
                  'ai-model-remove-${entry.config.connectionId}-${entry.model}',
                ),
                tooltip: l10n.aiModelRemove(entry.model),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 18,
                onPressed: busy
                    ? null
                    : () => onRemove(entry.config.connectionId, entry.model),
                icon: const Icon(Icons.close),
              ),
            Semantics(
              label: aiConnectionModelLabel(
                l10n,
                entry.config.copyWith(model: entry.model),
              ),
              child: Switch(
                key: ValueKey(
                  'ai-model-switch-${entry.config.connectionId}-${entry.model}',
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                value: enabled,
                onChanged: busy
                    ? null
                    : (bool enabled) => onEnabled(
                        entry.config.connectionId,
                        entry.model,
                        enabled: enabled,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiThinkingMenu extends StatefulWidget {
  const _AiThinkingMenu({
    required this.providerName,
    required this.model,
    required this.level,
    required this.choices,
    required this.enabled,
    required this.onSelected,
    this.onConfigure,
    this.omitted = false,
  });

  final String providerName;
  final String model;
  final AiThinkingLevel level;
  final List<AiThinkingLevel> choices;
  final bool enabled;
  final ValueChanged<AiThinkingLevel> onSelected;
  final VoidCallback? onConfigure;
  final bool omitted;

  @override
  State<_AiThinkingMenu> createState() => _AiThinkingMenuState();
}

class _AiThinkingMenuState extends State<_AiThinkingMenu> {
  final _fieldFocus = FocusNode();
  final _menuFocus = FocusNode();

  @override
  Widget build(BuildContext context) {
    final providerName = widget.providerName;
    final model = widget.model;
    final level = widget.level;
    final choices = widget.choices;
    final enabled = widget.enabled;
    final onSelected = widget.onSelected;
    final onConfigure = widget.onConfigure;
    final omitted = widget.omitted;
    final l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    const double menuWidth = 168;
    return MenuAnchor(
      childFocusNode: _fieldFocus,
      onOpen: _menuFocus.requestFocus,
      crossAxisUnconstrained: false,
      alignmentOffset: const Offset(0, 4),
      style: appMenuStyle(context, width: menuWidth),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: Text(
            l10n.aiThinking,
            style: text.labelLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        for (final AiThinkingLevel choice in choices)
          MenuItemButton(
            focusNode: choice == level ? _menuFocus : null,
            overflowAxis: Axis.vertical,
            onPressed: () => onSelected(choice),
            style: appMenuItemStyle(context, selected: choice == level),
            trailingIcon: choice == level
                ? const Icon(Icons.check, size: 18)
                : null,
            child: SizedBox(
              width: double.infinity,
              child: Text(aiThinkingLabel(l10n, choice)),
            ),
          ),
        if (onConfigure != null) ...[
          const Divider(height: 12),
          MenuItemButton(
            overflowAxis: Axis.vertical,
            focusNode: choices.isEmpty ? _menuFocus : null,
            onPressed: onConfigure,
            style: appMenuItemStyle(context),
            child: Text(l10n.aiThinkingSettings),
          ),
        ],
      ],
      builder: (context, controller, child) => InkWell(
        focusNode: _fieldFocus,
        key: ValueKey('ai-model-thinking-$providerName-$model'),
        borderRadius: BorderRadius.circular(999),
        onTap: !enabled
            ? null
            : () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
        child: Tooltip(
          message:
              '${l10n.aiThinking} ${omitted ? l10n.aiThinkingOmitShort : aiThinkingLabel(l10n, level)}',
          child: Container(
            constraints: const BoxConstraints(minHeight: 26),
            padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? colors.surfaceContainer
                  : colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    l10n.aiThinking,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: enabled
                          ? colors.onSurfaceVariant
                          : Theme.of(context).disabledColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    omitted
                        ? l10n.aiThinkingOmitShort
                        : aiThinkingLabel(l10n, level),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: enabled
                          ? colors.onSurfaceVariant
                          : Theme.of(context).disabledColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: enabled
                      ? colors.onSurfaceVariant
                      : Theme.of(context).disabledColor,
                ),
              ],
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

class _AiModelCatalogDialog extends StatefulWidget {
  const _AiModelCatalogDialog({
    super.key,
    required this.rows,
    required this.isBusy,
    required this.onEnabled,
    required this.onThinking,
    required this.onRemove,
    required this.onEditThinking,
  });

  final List<_AiModelEntry> Function() rows;
  final bool Function() isBusy;
  final void Function(String id, String model, {required bool enabled})
  onEnabled;
  final void Function(String connectionId, String model, AiThinkingLevel level)
  onThinking;
  final void Function(String connectionId, String model) onRemove;
  final Future<void> Function(String connectionId, String model) onEditThinking;

  @override
  State<_AiModelCatalogDialog> createState() => _AiModelCatalogDialogState();
}

class _AiModelCatalogDialogState extends State<_AiModelCatalogDialog> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<_AiModelEntry> rows = widget.rows();
    final bool busy = widget.isBusy();
    final double height = (MediaQuery.sizeOf(context).height - 200).clamp(
      140.0,
      640.0,
    );
    final sections = <({AiConnectionConfig config, List<_AiModelEntry> rows})>[
      for (final id in {for (final row in rows) row.config.connectionId})
        (
          config: rows.firstWhere((r) => r.config.connectionId == id).config,
          rows: rows.where((r) => r.config.connectionId == id).toList()
            ..sort(
              (left, right) =>
                  _compareModelIdsNewestFirst(left.model, right.model),
            ),
        ),
    ];
    return AiSettingsTheme(
      child: AppDialogShell(
        title: l10n.aiModel,
        content: SizedBox(
          width: 560,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final section in sections) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                      child: Text(
                        aiConnectionLabel(l10n, section.config),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (
                      var index = 0;
                      index < section.rows.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(height: 6),
                      _AiModelTile(
                        entry: section.rows[index],
                        showProvider: false,
                        busy: busy,
                        onEnabled: (id, model, {required bool enabled}) {
                          widget.onEnabled(id, model, enabled: enabled);
                          setState(() {});
                        },
                        onThinking: (id, model, level) {
                          widget.onThinking(id, model, level);
                          setState(() {});
                        },
                        onRemove: (id, model) {
                          widget.onRemove(id, model);
                          setState(() {});
                        },
                        onEditThinking: (id, model) async {
                          await widget.onEditThinking(id, model);
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonActionClose),
          ),
        ],
      ),
    );
  }
}

/// 版本數字由大到小。同一版再依名稱，沒有數字的名稱排在後面。
int _compareModelIdsNewestFirst(String left, String right) {
  final List<int> leftNumbers = _modelVersionNumbers(left);
  final List<int> rightNumbers = _modelVersionNumbers(right);
  final int length = leftNumbers.length > rightNumbers.length
      ? leftNumbers.length
      : rightNumbers.length;
  for (var index = 0; index < length; index++) {
    final int leftNumber = index < leftNumbers.length ? leftNumbers[index] : 0;
    final int rightNumber = index < rightNumbers.length
        ? rightNumbers[index]
        : 0;
    if (leftNumber != rightNumber) return rightNumber.compareTo(leftNumber);
  }
  return left.compareTo(right);
}

List<int> _modelVersionNumbers(String id) => [
  for (final Match match in RegExp(r'\d+').allMatches(id))
    int.parse(match.group(0)!),
];
