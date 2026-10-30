import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_prompt_resolver.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_settings.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_labels.dart';
import 'package:quill_diary/presentation/ai/ai_error_text.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_prompt_dialog.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

Future<bool> showAiConnectionSettingsDialog(
  BuildContext context, {
  AiConnectionConfig? initialConnection,
  bool? initialHidePersonNames,
}) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (_) => AiConnectionSettingsDialog(
        initialConnection: initialConnection,
        initialHidePersonNames: initialHidePersonNames,
      ),
    ) ??
    false;

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

class _AiConnectionSettingsDialogState
    extends ConsumerState<AiConnectionSettingsDialog>
    with WidgetsBindingObserver {
  final _apiKeyControllers = {
    for (final AiProvider provider in aiCatalogProviders)
      provider: TextEditingController(),
  };
  final _modelAddControllers = {
    for (final AiProvider provider in aiCatalogProviders)
      provider: TextEditingController(),
  };
  final _baseUrlController = TextEditingController();
  final _workspaceIdController = TextEditingController();
  final _claudeWorkspaceController = TextEditingController();
  final _credentials = <String, _AiCredentialDraft>{};
  AiConnectionConfig? _customCredential;
  int _credentialVersion = 0;
  bool _isApiKeyLoaded = true;
  final _connectionsByProvider = <AiProvider, AiConnectionConfig>{};
  AiProvider _selectedProvider = AiProvider.openai;
  AiApiProtocol _customProtocol = AiApiProtocol.chatCompletions;
  bool _settingsLoaded = false;
  AiProvider? _testingProvider;
  bool get _isTestingConnection => _testingProvider != null;
  int _connectionTestVersion = 0;
  String? _conversationOverride, _generationOverride;
  bool _hidePersonNames = true;
  bool _isLoadingSettings = true;
  bool _isSavingSettings = false;
  bool _isBackgrounded = false;
  bool _settingsScrollLocked = false;
  final _settingsScroll = ScrollController();
  List<({AiProvider provider, String model})> _modelOrder = const [];
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
          Navigator.of(context).pop(false);
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
      final store = ref.read(aiSettingsStoreProvider);
      final session = ref.read(appSessionProvider).session;
      if (session == null) throw StateError('尚未解鎖');
      final stored = await store.read(session);
      if (!mounted) return;
      final connections = stored.connection;
      final diary = stored.chatDiary;
      for (final provider in aiCatalogProviders) {
        final AiConnectionConfig? saved = connections.configs[provider];
        final AiConnectionConfig connectionConfig = saved == null
            ? defaultConnection(provider)
            : normalizeModelCatalog(saved);
        final apiKey = await store.readApiKey(connectionConfig);
        if (!mounted) return;
        _credentials[connectionConfig.credentialId] = _AiCredentialDraft(
          connectionConfig,
          apiKey,
        );
      }
      _connectionsByProvider
        ..clear()
        ..addAll(
          connections.configs.map(
            (AiProvider provider, AiConnectionConfig config) =>
                MapEntry(provider, normalizeModelCatalog(config)),
          ),
        );
      for (final AiProvider provider in aiCatalogProviders) {
        _connectionsByProvider.putIfAbsent(
          provider,
          () => defaultConnection(provider),
        );
      }
      _conversationOverride = diary.prompts.conversationOverride;
      _generationOverride = diary.prompts.generationOverride;
      _hidePersonNames = widget.initialHidePersonNames ?? diary.hidePersonNames;
      final initial = widget.initialConnection;
      if (initial != null) {
        final apiKey = await store.readApiKey(initial);
        if (!mounted) return;
        final AiConnectionConfig prepared =
            _connectionsByProvider[initial.provider] ??
            defaultConnection(initial.provider);
        final AiConnectionConfig adopted =
            prepared.credentialId == initial.credentialId
            ? prepared
            : normalizeModelCatalog(initial);
        _connectionsByProvider[initial.provider] = adopted;
        _credentials[adopted.credentialId] = _AiCredentialDraft(
          adopted,
          apiKey,
        );
      }
      _restoreFields(initial?.provider ?? connections.provider);
      _modelOrder = [
        for (final _AiModelEntry row in _modelRows())
          (provider: row.provider, model: row.model),
      ];
      setState(() {
        _isLoadingSettings = false;
        _settingsLoaded = true;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _isLoadingSettings = false;
        });
        _showError(AiErrorCode.storage);
      }
    }
  }

  void _restoreFields(AiProvider active) {
    _selectedProvider = active;
    for (final AiProvider provider in aiCatalogProviders) {
      _connectionsByProvider[provider] = normalizeModelCatalog(
        _connectionsByProvider[provider] ?? defaultConnection(provider),
      );
    }
    final AiConnectionConfig custom =
        _connectionsByProvider[AiProvider.custom]!;
    _baseUrlController.text = custom.baseUrl;
    _workspaceIdController.text = custom.workspaceId;
    _customProtocol = custom.customProtocol;
    _customCredential = custom;
    _claudeWorkspaceController.text =
        _connectionsByProvider[AiProvider.claude]!.workspaceId;
    for (final AiProvider provider in aiCatalogProviders) {
      final AiConnectionConfig config = _connectionsByProvider[provider]!;
      _apiKeyControllers[provider]!.text =
          _credentials[config.credentialId]?.apiKey ?? '';
    }
    _isApiKeyLoaded = true;
  }

  AiConnectionConfig _edited(AiProvider provider) {
    final AiConnectionConfig stored = normalizeModelCatalog(
      _connectionsByProvider[provider] ?? defaultConnection(provider),
    );
    return switch (provider) {
      AiProvider.custom => stored.copyWith(
        baseUrl: _baseUrlController.text.trim(),
        workspaceId: _workspaceIdController.text.trim(),
        customProtocol: _customProtocol,
      ),
      AiProvider.claude => stored.copyWith(
        workspaceId: _claudeWorkspaceController.text.trim(),
      ),
      _ => stored,
    };
  }

  void _replaceProviderConfig(
    AiProvider provider,
    AiConnectionConfig connectionConfig,
  ) {
    _connectionsByProvider[provider] = connectionConfig;
    if (provider == AiProvider.custom) {
      _customCredential = connectionConfig;
    }
  }

  void _capture(AiProvider provider) {
    final AiConnectionConfig connectionConfig = _edited(provider);
    _replaceProviderConfig(provider, connectionConfig);
    if (provider == AiProvider.custom && !_isApiKeyLoaded) return;
    _credentials[connectionConfig.credentialId] = _AiCredentialDraft(
      connectionConfig,
      _apiKeyControllers[provider]!.text,
    );
  }

  void _addModel(AiProvider provider) {
    final String name = _modelAddControllers[provider]!.text;
    if (name.trim().isEmpty) return;
    setState(() {
      _replaceProviderConfig(provider, addModel(_edited(provider), name));
      _modelAddControllers[provider]!.clear();
    });
  }

  Future<void> _urlChanged(String _) async {
    final AiConnectionConfig? previous = _customCredential;
    final TextEditingController apiKey = _apiKeyControllers[AiProvider.custom]!;
    if (previous != null && _isApiKeyLoaded) {
      _credentials[previous.credentialId] = _AiCredentialDraft(
        previous,
        apiKey.text,
      );
    }
    final AiConnectionConfig connectionConfig = _edited(AiProvider.custom);
    _replaceProviderConfig(AiProvider.custom, connectionConfig);
    final int version = ++_credentialVersion;
    final _AiCredentialDraft? known =
        _credentials[connectionConfig.credentialId];
    if (known != null) {
      setState(() {
        apiKey.text = known.apiKey;
        _isApiKeyLoaded = true;
      });
      _credentials[connectionConfig.credentialId] = _AiCredentialDraft(
        connectionConfig,
        known.apiKey,
      );
      return;
    }
    setState(() {
      apiKey.text = '';
      _isApiKeyLoaded = false;
    });
    try {
      final String loaded = await ref
          .read(aiSettingsStoreProvider)
          .readApiKey(connectionConfig);
      if (!mounted || version != _credentialVersion) return;
      setState(() {
        apiKey.text = loaded;
        _isApiKeyLoaded = true;
      });
      _credentials[connectionConfig.credentialId] = _AiCredentialDraft(
        connectionConfig,
        loaded,
      );
    } on Object {
      if (mounted && version == _credentialVersion) {
        _showError(AiErrorCode.storage);
      }
    }
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
    _testingProvider = null;
  }

  bool _connectionIsCurrent(int version) =>
      !_isBackgrounded &&
      version == _connectionTestVersion &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _testConnection(AiProvider provider) async {
    if (_isBusy || (provider == AiProvider.custom && !_isApiKeyLoaded)) return;
    final version = ++_connectionTestVersion;
    FocusScope.of(context).unfocus();
    setState(() => _testingProvider = provider);
    AiClient? client;
    try {
      _capture(provider);
      final AiConnectionConfig connectionConfig = _edited(provider);
      validateAiEndpoint(connectionConfig);
      final String apiKey = _apiKeyControllers[provider]!.text.trim();
      if (!connectionConfig.isConfigured ||
          (provider.requiresApiKey && apiKey.isEmpty)) {
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
        setState(() => _testingProvider = null);
      }
    }
  }

  Future<T?> _withoutOuterScroll<T>(Future<T?> Function() open) async {
    final double saved = _settingsScroll.hasClients
        ? _settingsScroll.offset
        : 0;
    setState(() => _settingsScrollLocked = true);
    _holdSettingsScroll(saved);
    try {
      return await open();
    } finally {
      if (mounted) {
        setState(() => _settingsScrollLocked = false);
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

  Future<void> _editPrompt(ChatDiaryPromptPurpose purpose) async {
    final conversation = purpose == ChatDiaryPromptPurpose.conversation;
    final result = await _withoutOuterScroll(
      () => showChatDiaryPromptDialog(
        context,
        purpose: purpose,
        customText: conversation ? _conversationOverride : _generationOverride,
      ),
    );
    if (mounted && result != null) {
      setState(() {
        if (conversation) {
          _conversationOverride = result.customText;
        } else {
          _generationOverride = result.customText;
        }
      });
    }
  }

  bool _hasSelectableChatModel() {
    final AiConnectionSettings settings = AiConnectionSettings(
      provider: _selectedProvider,
      configs: {
        for (final AiProvider provider in aiCatalogProviders)
          provider: _edited(provider),
      },
    );
    final ({List<ChatModelOption> models, bool currentIsExtra}) menu =
        chatModelMenu(
          settings: settings,
          chatConfig: _edited(_selectedProvider),
          hasApiKey: (AiProvider provider) =>
              _apiKeyControllers[provider]!.text.trim().isNotEmpty,
        );
    final int selectable = menu.models.length - (menu.currentIsExtra ? 1 : 0);
    return selectable > 0;
  }

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
    if (!_hasSelectableChatModel()) {
      setState(() {});
      return;
    }
    setState(() {
      _isSavingSettings = true;
    });
    try {
      for (final AiProvider provider in aiCatalogProviders) {
        _capture(provider);
      }
      final AiConnectionConfig custom = _edited(AiProvider.custom);
      if (custom.baseUrl.trim().isNotEmpty) {
        validateAiEndpoint(custom);
      }
      validateAiEndpoint(_edited(_selectedProvider));
      final store = ref.read(aiSettingsStoreProvider);
      final session = ref.read(appSessionProvider).session;
      if (session == null) throw StateError('尚未解鎖');
      for (final credential in _credentials.values) {
        await store.saveApiKey(credential.connectionConfig, credential.apiKey);
      }
      await store.save(
        session,
        connection: AiConnectionSettings(
          provider: _selectedProvider,
          configs: Map.of(_connectionsByProvider),
        ),
        chatDiary: ChatDiarySettings(
          prompts: ChatDiaryPromptSettings(
            conversationOverride: _conversationOverride,
            generationOverride: _generationOverride,
          ),
          hidePersonNames: _hidePersonNames,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on AiFailure catch (error) {
      if (mounted) {
        _showError(error.code);
      }
    } on FormatException {
      if (mounted) {
        _showError(AiErrorCode.configuration);
      }
    } on Object {
      if (mounted) {
        _showError(AiErrorCode.storage);
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingSettings = false);
      }
    }
  }

  Widget _promptTile(ChatDiaryPromptPurpose purpose) {
    final l10n = context.l10n;
    final conversation = purpose == ChatDiaryPromptPurpose.conversation;
    final custom = conversation ? _conversationOverride : _generationOverride;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(
        conversation ? Icons.forum_outlined : Icons.article_outlined,
      ),
      title: Text(
        conversation
            ? l10n.chatDiaryConversationPrompt
            : l10n.chatDiaryGenerationPrompt,
      ),
      subtitle: Text(
        custom == null
            ? l10n.chatDiaryBuiltInPrompt
            : l10n.chatDiaryCustomPrompt,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _isBusy ? null : () => _editPrompt(purpose),
    );
  }

  List<_AiModelEntry> _modelRows() {
    final List<_AiModelEntry> enabled = [];
    final List<_AiModelEntry> disabled = [];
    for (final AiProvider provider in aiCatalogProviders) {
      final AiConnectionConfig config = normalizeModelCatalog(
        _connectionsByProvider[provider] ?? defaultConnection(provider),
      );
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

  List<_AiModelEntry> _stableModelRows() {
    final List<_AiModelEntry> current = _modelRows();
    final Map<String, _AiModelEntry> byId = {
      for (final _AiModelEntry row in current)
        '${row.provider.name}\u0000${row.model}': row,
    };
    final List<_AiModelEntry> ordered = [];
    final Set<String> seen = {};
    for (final ({AiProvider provider, String model}) item in _modelOrder) {
      final String id = '${item.provider.name}\u0000${item.model}';
      final _AiModelEntry? row = byId[id];
      if (row == null) continue;
      ordered.add(row);
      seen.add(id);
    }
    for (final _AiModelEntry row in current) {
      final String id = '${row.provider.name}\u0000${row.model}';
      if (seen.add(id)) ordered.add(row);
    }
    return ordered;
  }

  void _setListedModelEnabled(
    AiProvider provider,
    String model, {
    required bool enabled,
  }) {
    setState(() {
      _replaceProviderConfig(
        provider,
        setModelEnabled(_edited(provider), model, enabled: enabled),
      );
    });
  }

  void _setThinkingLevel(
    AiProvider provider,
    String model,
    AiThinkingLevel level,
  ) {
    setState(() {
      _replaceProviderConfig(
        provider,
        setThinkingLevel(_edited(provider), model, level),
      );
    });
  }

  void _removeListedModel(AiProvider provider, String model) {
    setState(() {
      _replaceProviderConfig(
        provider,
        removeAddedModel(_edited(provider), model),
      );
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
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0) const Divider(height: 1),
          _AiModelTile(
            entry: visible[index],
            busy: _isBusy,
            onEnabled: _setListedModelEnabled,
            onThinking: _setThinkingLevel,
            onRemove: _removeListedModel,
          ),
        ],
        if (rows.length > previewCount)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              key: const ValueKey('ai-model-show-more'),
              onPressed: _isBusy ? null : _openModelCatalog,
              child: Text(l10n.aiModelShowMore),
            ),
          ),
      ],
    );
  }

  Widget _providerSection(AppLocalizations l10n, AiProvider provider) {
    final String query = _modelAddControllers[provider]!.text.trim();
    final bool custom = provider == AiProvider.custom;
    final TextStyle? notice = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          aiProviderLabel(l10n, provider),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (provider == AiProvider.gemini)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l10n.aiGeminiPolicyNotice, style: notice),
          ),
        if (custom) ...[
          const SizedBox(height: 8),
          _AiOptionField<AiApiProtocol>(
            key: const ValueKey('ai-protocol-field'),
            label: l10n.aiProtocol,
            value: _customProtocol,
            options: [
              for (final AiApiProtocol protocol in AiApiProtocol.values)
                (protocol, aiProtocolLabel(protocol)),
            ],
            onChanged: _isBusy
                ? null
                : (AiApiProtocol value) {
                    if (value == _customProtocol) return;
                    setState(() => _customProtocol = value);
                  },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _baseUrlController,
            enabled: !_isBusy,
            keyboardType: TextInputType.url,
            onChanged: _urlChanged,
            decoration: InputDecoration(
              labelText: l10n.aiServerUrl,
              hintText: switch (_customProtocol) {
                AiApiProtocol.ollamaChat => 'http://192.168.1.100:11434',
                AiApiProtocol.geminiContent => 'https://example.com/v1beta',
                _ => 'https://example.com/v1',
              },
            ),
          ),
          if (Uri.tryParse(_edited(provider).effectiveBaseUrl)?.scheme ==
              'http')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.aiHttpNotice, style: notice),
            ),
        ],
        const SizedBox(height: 10),
        TextField(
          key: ValueKey('ai-api-key-${provider.name}'),
          controller: _apiKeyControllers[provider],
          enabled: !_isBusy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) {
            if (custom) {
              _credentialVersion++;
              _isApiKeyLoaded = true;
            }
            _capture(provider);
            setState(() {});
          },
          decoration: InputDecoration(labelText: l10n.aiApiKey),
        ),
        if (provider == AiProvider.claude ||
            (custom && _customProtocol == AiApiProtocol.claudeMessages)) ...[
          const SizedBox(height: 10),
          TextField(
            controller: provider == AiProvider.claude
                ? _claudeWorkspaceController
                : _workspaceIdController,
            enabled: !_isBusy,
            onChanged: (_) => _capture(provider),
            decoration: InputDecoration(labelText: l10n.aiWorkspace),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          key: ValueKey('ai-model-add-field-${provider.name}'),
          controller: _modelAddControllers[provider],
          enabled: !_isBusy,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _addModel(provider),
          decoration: InputDecoration(
            hintText: l10n.aiModelSearch,
            suffixIcon: IconButton(
              key: ValueKey('ai-model-add-${provider.name}'),
              tooltip: query.isEmpty
                  ? l10n.aiModelSearch
                  : l10n.aiModelAdd(query),
              onPressed: _isBusy || query.isEmpty
                  ? null
                  : () => _addModel(provider),
              icon: const Icon(Icons.add),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: AppActionButton(
            key: ValueKey('ai-test-${provider.name}'),
            label: l10n.aiTestConnection,
            icon: Icons.wifi_tethering,
            appearance: AppActionButtonAppearance.outlined,
            loading: _testingProvider == provider,
            onPressed: _isBusy || (custom && !_isApiKeyLoaded)
                ? null
                : () => _testConnection(provider),
          ),
        ),
      ],
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
            label: l10n.chatDiaryContentHidden,
            child: const Icon(Icons.lock_outline),
          ),
        ),
      );
    }
    final height = (MediaQuery.sizeOf(context).height - 200).clamp(
      140.0,
      640.0,
    );
    final Widget dialog = AppDialogShell(
      title: l10n.aiSettings,
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height),
          child: _isLoadingSettings
              ? const Center(child: CircularProgressIndicator())
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
                      _sectionCard(
                        title: l10n.chatDiarySettingsSection,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.chatDiaryHidePeople),
                            subtitle: Text(l10n.chatDiaryHidePeopleHint),
                            value: _hidePersonNames,
                            onChanged: _isBusy
                                ? null
                                : (value) =>
                                      setState(() => _hidePersonNames = value),
                          ),
                          const Divider(height: 1),
                          _promptTile(ChatDiaryPromptPurpose.conversation),
                          const Divider(height: 1),
                          _promptTile(ChatDiaryPromptPurpose.generation),
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
                          for (
                            var index = 0;
                            index < aiCatalogProviders.length;
                            index++
                          ) ...[
                            if (index > 0) const Divider(height: 28),
                            _providerSection(l10n, aiCatalogProviders[index]),
                          ],
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
          onPressed: _isBusy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.commonActionCancel),
        ),
        FilledButton(
          onPressed: !_settingsLoaded || _isBusy || !_isApiKeyLoaded
              ? null
              : _save,
          child: Text(l10n.aiSaveSettings),
        ),
      ],
    );
    if (!_settingsScrollLocked) return dialog;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
      child: dialog,
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
    for (final TextEditingController controller in [
      ..._apiKeyControllers.values,
      ..._modelAddControllers.values,
      _baseUrlController,
      _workspaceIdController,
      _claudeWorkspaceController,
    ]) {
      controller.dispose();
    }
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
  });

  final _AiModelEntry entry;
  final bool busy;
  final void Function(
    AiProvider provider,
    String model, {
    required bool enabled,
  })
  onEnabled;
  final void Function(AiProvider provider, String model, AiThinkingLevel level)
  onThinking;
  final void Function(AiProvider provider, String model) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool removable = !entry.config.isBuiltinModel(entry.model);
    final choices = thinkingChoicesFor(entry.config, entry.model);
    final controls = <Widget>[
      if (choices.isNotEmpty)
        _AiThinkingMenu(
          providerName: entry.provider.name,
          model: entry.model,
          level: resolvedThinkingLevel(entry.config, entry.model),
          choices: choices,
          enabled: !busy,
          onSelected: (AiThinkingLevel level) =>
              onThinking(entry.provider, entry.model, level),
        ),
      if (removable)
        IconButton(
          key: ValueKey(
            'ai-model-remove-${entry.provider.name}-${entry.model}',
          ),
          tooltip: l10n.aiModelRemove(entry.model),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          iconSize: 18,
          onPressed: busy ? null : () => onRemove(entry.provider, entry.model),
          icon: const Icon(Icons.close),
        ),
      Switch(
        key: ValueKey('ai-model-switch-${entry.provider.name}-${entry.model}'),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        value: entry.config.enabledModels.contains(entry.model),
        onChanged: busy
            ? null
            : (bool enabled) =>
                  onEnabled(entry.provider, entry.model, enabled: enabled),
      ),
    ];
    final title = Text(
      aiModelOptionLabel(l10n, entry.provider, entry.model),
      style: Theme.of(context).textTheme.bodyMedium,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    return LayoutBuilder(
      key: ValueKey('ai-model-${entry.provider.name}-${entry.model}'),
      builder: (context, constraints) {
        if (constraints.maxWidth < 480 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: controls,
                ),
              ],
            ),
          );
        }
        return ListTile(
          visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          minVerticalPadding: 0,
          title: title,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: controls),
        );
      },
    );
  }
}

class _AiThinkingMenu extends StatelessWidget {
  const _AiThinkingMenu({
    required this.providerName,
    required this.model,
    required this.level,
    required this.choices,
    required this.enabled,
    required this.onSelected,
  });

  final String providerName;
  final String model;
  final AiThinkingLevel level;
  final List<AiThinkingLevel> choices;
  final bool enabled;
  final ValueChanged<AiThinkingLevel> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    const double menuWidth = 168;
    return MenuAnchor(
      crossAxisUnconstrained: true,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerLow),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: const WidgetStatePropertyAll(Size(menuWidth, 0)),
        maximumSize: const WidgetStatePropertyAll(Size(menuWidth, 320)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
      ),
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
            onPressed: () => onSelected(choice),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(
                Size(menuWidth - 12, 40),
              ),
              backgroundColor: WidgetStatePropertyAll(
                choice == level
                    ? colors.surfaceContainerHighest
                    : Colors.transparent,
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Text(aiThinkingLabel(l10n, choice)),
            ),
          ),
      ],
      builder: (context, controller, child) => InkWell(
        key: ValueKey('ai-model-thinking-$providerName-$model'),
        borderRadius: BorderRadius.circular(16),
        onTap: !enabled
            ? null
            : () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.aiThinking,
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              Text(aiThinkingLabel(l10n, level), style: text.bodySmall),
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: enabled ? colors.onSurfaceVariant : colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
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
  });

  final List<_AiModelEntry> Function() rows;
  final bool Function() isBusy;
  final void Function(
    AiProvider provider,
    String model, {
    required bool enabled,
  })
  onEnabled;
  final void Function(AiProvider provider, String model, AiThinkingLevel level)
  onThinking;
  final void Function(AiProvider provider, String model) onRemove;

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
    final List<({AiProvider provider, List<_AiModelEntry> rows})> sections = [
      for (final AiProvider provider in aiCatalogProviders)
        (
          provider: provider,
          rows:
              [
                for (final _AiModelEntry row in rows)
                  if (row.provider == provider) row,
              ]..sort(
                (_AiModelEntry left, _AiModelEntry right) =>
                    _compareModelIdsNewestFirst(left.model, right.model),
              ),
        ),
    ].where((section) => section.rows.isNotEmpty).toList();
    return AppDialogShell(
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
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                    child: Text(
                      aiProviderLabel(l10n, section.provider),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (var index = 0; index < section.rows.length; index++) ...[
                    if (index > 0) const Divider(height: 1),
                    _AiModelTile(
                      entry: section.rows[index],
                      busy: busy,
                      onEnabled: (provider, model, {required bool enabled}) {
                        widget.onEnabled(provider, model, enabled: enabled);
                        setState(() {});
                      },
                      onThinking: (provider, model, level) {
                        widget.onThinking(provider, model, level);
                        setState(() {});
                      },
                      onRemove: (provider, model) {
                        widget.onRemove(provider, model);
                        setState(() {});
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
    );
  }
}

class _AiOptionField<T> extends StatelessWidget {
  const _AiOptionField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String selected = options
        .firstWhere((option) => option.$1 == value)
        .$2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        return MenuAnchor(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerLow),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shadowColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(0),
            minimumSize: WidgetStatePropertyAll(Size(width, 0)),
            maximumSize: WidgetStatePropertyAll(Size(width, 320)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.outlineVariant),
              ),
            ),
            padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          ),
          menuChildren: [
            for (final (option, text) in options)
              MenuItemButton(
                onPressed: onChanged == null ? null : () => onChanged!(option),
                style: ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(width - 12, 40)),
                  backgroundColor: WidgetStatePropertyAll(
                    option == value
                        ? colors.surfaceContainerHighest
                        : Colors.transparent,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
          builder: (context, controller, child) => InkWell(
            onTap: onChanged == null
                ? null
                : () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                enabled: onChanged != null,
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              child: Text(
                selected,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
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
