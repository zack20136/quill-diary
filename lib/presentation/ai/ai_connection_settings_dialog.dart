import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/ai/ai_connection_providers.dart';
import '../../application/chat_diary/chat_diary_prompt_resolver.dart';
import '../../application/chat_diary/chat_diary_providers.dart';
import '../../application/session/providers/session_providers.dart';
import '../../application/session/state/app_session_state.dart';
import '../../domain/ai/ai_connection_settings.dart';
import '../../domain/chat_diary/chat_diary_settings.dart';
import '../../infrastructure/ai/ai_client.dart';
import '../../l10n/l10n.dart';
import '../../shared/presentation/app_feedback.dart';
import '../../shared/presentation/widgets/app_action_button.dart';
import '../../shared/presentation/widgets/app_dialog_shell.dart';
import '../chat_diary/chat_diary_prompt_dialog.dart';
import 'ai_connection_labels.dart';
import 'ai_error_text.dart';

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
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _workspaceIdController = TextEditingController();
  final _modelController = TextEditingController();
  final _modelFocusNode = FocusNode();
  final _modelMenuController = MenuController();
  final _credentials = <String, _AiCredentialDraft>{};
  AiConnectionConfig? _credentialConnection;
  int _credentialVersion = 0;
  int _modelsRequestVersion = 0;
  String? _modelsLoadedFor;
  bool _isApiKeyLoaded = true;
  final _connectionsByProvider = <AiProvider, AiConnectionConfig>{};
  AiProvider _selectedProvider = AiProvider.openai;
  AiApiProtocol _selectedProtocol = AiApiProtocol.chatCompletions;
  bool _settingsLoaded = false;
  bool _isTestingConnection = false;
  int _connectionTestVersion = 0;
  String? _conversationOverride, _generationOverride;
  bool _hidePersonNames = true;
  bool _isLoadingSettings = true;
  bool _isSavingSettings = false;
  bool _isLoadingModels = false;
  bool _isBackgrounded = false;
  bool get _isBusy => _isTestingConnection || _isSavingSettings;
  AiClient? _modelListClient;
  AiClient? _connectionTestClient;
  List<String> _models = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(appSessionProvider, (_, next) {
      if (next.status == AppLockStatus.locked ||
          next.status == AppLockStatus.recoveryRequired) {
        _cancelConnectionTest();
        _invalidateModels();
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
      _invalidateModels();
      _modelFocusNode.unfocus();
      _modelMenuController.close();
    }
    if (mounted) {
      setState(() => _isBackgrounded = state != AppLifecycleState.resumed);
    }
  }

  Future<void> _load() async {
    try {
      final store = ref.read(aiConnectionSettingsStoreProvider);
      final diaryStore = ref.read(chatDiarySettingsStoreProvider);
      final connections = await store.read();
      if (!mounted) return;
      final diary = await diaryStore.read();
      if (!mounted) return;
      for (final provider in AiProvider.values) {
        final connectionConfig = connections.configFor(provider);
        final apiKey = await store.readApiKey(connectionConfig);
        if (!mounted) return;
        _credentials[connectionConfig.credentialId] = _AiCredentialDraft(
          connectionConfig,
          apiKey,
        );
      }
      _connectionsByProvider.addAll(connections.configs);
      _conversationOverride = diary.prompts.conversationOverride;
      _generationOverride = diary.prompts.generationOverride;
      _hidePersonNames = widget.initialHidePersonNames ?? diary.hidePersonNames;
      final initial = widget.initialConnection;
      if (initial != null) {
        final apiKey = await store.readApiKey(initial);
        if (!mounted) return;
        _connectionsByProvider[initial.provider] = initial;
        _credentials[initial.credentialId] = _AiCredentialDraft(
          initial,
          apiKey,
        );
      }
      _selectProvider(initial?.provider ?? connections.provider);
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

  void _selectProvider(AiProvider provider) {
    _credentialVersion++;
    _modelFocusNode.unfocus();
    final connectionConfig =
        _connectionsByProvider[provider] ??
        AiConnectionConfig(provider: provider);
    _selectedProvider = provider;
    _selectedProtocol = connectionConfig.customProtocol;
    _modelController.text = connectionConfig.model;
    _baseUrlController.text = connectionConfig.baseUrl;
    _workspaceIdController.text = connectionConfig.workspaceId;
    _credentialConnection = connectionConfig;
    _apiKeyController.text =
        _credentials[connectionConfig.credentialId]?.apiKey ?? '';
    _isApiKeyLoaded = true;
    _invalidateModels();
  }

  AiConnectionConfig get _currentConfig => AiConnectionConfig(
    provider: _selectedProvider,
    model: _modelController.text.trim(),
    baseUrl: _baseUrlController.text.trim(),
    workspaceId: _workspaceIdController.text.trim(),
    customProtocol: _selectedProtocol,
  );

  void _captureApiKey() {
    final connectionConfig = _credentialConnection;
    if (connectionConfig == null || !_isApiKeyLoaded) return;
    _credentials[connectionConfig.credentialId] = _AiCredentialDraft(
      connectionConfig,
      _apiKeyController.text,
    );
  }

  AiConnectionConfig _captureConnection() {
    _captureApiKey();
    final connectionConfig = _currentConfig;
    _connectionsByProvider[_selectedProvider] = connectionConfig;
    return connectionConfig;
  }

  void _invalidateModels() {
    _modelMenuController.close();
    _modelsRequestVersion++;
    _modelListClient?.close();
    _modelListClient = null;
    _isLoadingModels = false;
    _models = [];
    _modelsLoadedFor = null;
  }

  Future<void> _urlChanged(String _) async {
    _captureApiKey();
    final connectionConfig = _currentConfig;
    _credentialConnection = connectionConfig;
    final version = ++_credentialVersion;
    setState(() {
      _apiKeyController.text =
          _credentials[connectionConfig.credentialId]?.apiKey ?? '';
      _isApiKeyLoaded = _credentials.containsKey(connectionConfig.credentialId);
      _invalidateModels();
    });
    if (_credentials.containsKey(connectionConfig.credentialId)) return;
    try {
      final apiKey = await ref
          .read(aiConnectionSettingsStoreProvider)
          .readApiKey(connectionConfig);
      if (!mounted || version != _credentialVersion) return;
      setState(() {
        _apiKeyController.text = apiKey;
        _isApiKeyLoaded = true;
      });
      _credentials[connectionConfig.credentialId] = _AiCredentialDraft(
        connectionConfig,
        apiKey,
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

  List<String> get _matchingModels => _models
      .where(
        (model) =>
            model.toLowerCase().contains(_modelController.text.toLowerCase()),
      )
      .toList();

  void _syncModelMenu() {
    if (!_isBusy &&
        !_isBackgrounded &&
        _modelFocusNode.hasFocus &&
        _matchingModels.isNotEmpty) {
      _modelMenuController.open();
    } else {
      _modelMenuController.close();
    }
  }

  Future<void> _loadModels() async {
    if (_isBusy || !_isApiKeyLoaded || _isLoadingModels) return;
    final connectionConfig = _captureConnection();
    final cacheKey =
        '${connectionConfig.credentialId}:${connectionConfig.protocol.name}:${_apiKeyController.text}';
    if (_modelsLoadedFor == cacheKey ||
        connectionConfig.effectiveBaseUrl.isEmpty ||
        (_selectedProvider.requiresApiKey &&
            _apiKeyController.text.trim().isEmpty)) {
      return;
    }
    final version = ++_modelsRequestVersion;
    setState(() {
      _isLoadingModels = true;
    });
    AiClient? client;
    try {
      validateAiEndpoint(connectionConfig);
      client = ref.read(aiClientFactoryProvider)(
        connectionConfig,
        _apiKeyController.text.trim(),
      );
      _modelListClient = client;
      final models = await client.listModels().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          client?.close();
          throw const AiFailure(AiErrorCode.timeout);
        },
      );
      if (mounted &&
          version == _modelsRequestVersion &&
          !_isBackgrounded &&
          ModalRoute.of(context)?.isCurrent == true &&
          _currentConfig.credentialId == connectionConfig.credentialId &&
          cacheKey ==
              '${_currentConfig.credentialId}:${_currentConfig.protocol.name}:${_apiKeyController.text}') {
        setState(() {
          _models = List<String>.of(models)..sort();
          _modelsLoadedFor = cacheKey;
        });
      }
    } on Object {
      // 模型清單僅提供輸入建議；查詢失敗不打斷手動輸入。
    } finally {
      client?.close();
      if (_modelListClient == client) _modelListClient = null;
      if (mounted && version == _modelsRequestVersion) {
        setState(() => _isLoadingModels = false);
      }
    }
  }

  Future<void> _openModels() async {
    await _loadModels();
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      _syncModelMenu();
    }
  }

  void _cancelConnectionTest() {
    _connectionTestVersion++;
    _connectionTestClient?.close();
    _connectionTestClient = null;
    _isTestingConnection = false;
  }

  bool _connectionIsCurrent(int version) =>
      !_isBackgrounded &&
      version == _connectionTestVersion &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _testConnection() async {
    if (_isBusy || !_isApiKeyLoaded) return;
    final version = ++_connectionTestVersion;
    if (_isLoadingModels) _invalidateModels();
    _modelMenuController.close();
    FocusScope.of(context).unfocus();
    setState(() {
      _isTestingConnection = true;
    });
    AiClient? client;
    try {
      final connectionConfig = _captureConnection();
      validateAiEndpoint(connectionConfig);
      if (!connectionConfig.isConfigured ||
          (_selectedProvider.requiresApiKey &&
              _apiKeyController.text.trim().isEmpty)) {
        throw const AiFailure(AiErrorCode.configuration);
      }
      client = ref.read(aiClientFactoryProvider)(
        connectionConfig,
        _apiKeyController.text.trim(),
      );
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
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Future<void> _editPrompt(ChatDiaryPromptPurpose purpose) async {
    final conversation = purpose == ChatDiaryPromptPurpose.conversation;
    final result = await showChatDiaryPromptDialog(
      context,
      purpose: purpose,
      customText: conversation ? _conversationOverride : _generationOverride,
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

  Future<void> _save() async {
    if (!_settingsLoaded) return;
    if (_isLoadingModels) _invalidateModels();
    _modelMenuController.close();
    setState(() {
      _isSavingSettings = true;
    });
    try {
      final connectionConfig = _captureConnection();
      validateAiEndpoint(connectionConfig);
      final store = ref.read(aiConnectionSettingsStoreProvider);
      final diaryStore = ref.read(chatDiarySettingsStoreProvider);
      for (final credential in _credentials.values) {
        await store.saveApiKey(credential.connectionConfig, credential.apiKey);
      }
      await store.save(
        AiConnectionSettings(
          provider: _selectedProvider,
          configs: Map.of(_connectionsByProvider),
        ),
      );
      await diaryStore.save(
        ChatDiarySettings(
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
    final height =
        (MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom -
                200)
            .clamp(140.0, 640.0);
    return AppDialogShell(
      title: l10n.aiSettings,
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height),
          child: _isLoadingSettings
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.aiSettingsHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_selectedProvider == AiProvider.gemini)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            l10n.aiGeminiPolicyNotice,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (Uri.tryParse(_currentConfig.effectiveBaseUrl)
                              ?.scheme ==
                          'http')
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            l10n.aiHttpNotice,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AiProvider>(
                        key: ValueKey(_selectedProvider),
                        initialValue: _selectedProvider,
                        decoration: InputDecoration(labelText: l10n.aiProvider),
                        items: [
                          for (final provider in AiProvider.values)
                            DropdownMenuItem(
                              value: provider,
                              child: Text(aiProviderLabel(l10n, provider)),
                            ),
                        ],
                        onChanged: _isBusy
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() {
                                    _captureConnection();
                                    _selectProvider(value);
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                      if (_selectedProvider == AiProvider.custom) ...[
                        DropdownButtonFormField<AiApiProtocol>(
                          key: ValueKey(
                            'ai-protocol-${_selectedProtocol.name}',
                          ),
                          initialValue: _selectedProtocol,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.aiProtocol,
                          ),
                          items: [
                            for (final protocol in AiApiProtocol.values)
                              DropdownMenuItem(
                                value: protocol,
                                child: Text(
                                  aiProtocolLabel(protocol),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _isBusy
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedProtocol = value;
                                      _invalidateModels();
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_selectedProvider.hasCustomUrl) ...[
                        TextField(
                          controller: _baseUrlController,
                          enabled: !_isBusy,
                          keyboardType: TextInputType.url,
                          onChanged: _urlChanged,
                          decoration: InputDecoration(
                            labelText: l10n.aiServerUrl,
                            hintText:
                                _selectedProtocol == AiApiProtocol.ollamaChat
                                ? 'http://192.168.1.100:11434'
                                : _selectedProtocol ==
                                      AiApiProtocol.geminiContent
                                ? 'https://example.com/v1beta'
                                : 'https://example.com/v1',
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      MenuAnchor(
                        controller: _modelMenuController,
                        childFocusNode: _modelFocusNode,
                        style: MenuStyle(
                          maximumSize: WidgetStatePropertyAll(
                            Size(
                              (MediaQuery.sizeOf(context).width - 96).clamp(
                                180.0,
                                520.0,
                              ),
                              220,
                            ),
                          ),
                        ),
                        menuChildren: [
                          for (final model in _matchingModels)
                            MenuItemButton(
                              onPressed: () {
                                setState(() => _modelController.text = model);
                                _modelMenuController.close();
                              },
                              child: Text(model),
                            ),
                        ],
                        builder: (context, menu, child) => TextField(
                          key: const ValueKey('ai-model-autocomplete'),
                          controller: _modelController,
                          focusNode: _modelFocusNode,
                          enabled: !_isBusy,
                          autocorrect: false,
                          onTap: _openModels,
                          onChanged: (_) {
                            setState(() {});
                            _syncModelMenu();
                          },
                          decoration: InputDecoration(
                            labelText: l10n.aiModel,
                            suffixIcon: _isLoadingModels
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.arrow_drop_down),
                                    tooltip: l10n.aiSelectModel,
                                    onPressed: _isBusy
                                        ? null
                                        : () {
                                            _modelFocusNode.requestFocus();
                                            unawaited(_openModels());
                                          },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _apiKeyController,
                        enabled: !_isBusy,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        onChanged: (_) {
                          _credentialVersion++;
                          _isApiKeyLoaded = true;
                          _credentialConnection = _currentConfig;
                          _captureApiKey();
                          setState(_invalidateModels);
                        },
                        decoration: InputDecoration(labelText: l10n.aiApiKey),
                      ),
                      if (_currentConfig.protocol ==
                          AiApiProtocol.claudeMessages) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _workspaceIdController,
                          enabled: !_isBusy,
                          onChanged: (_) => setState(_invalidateModels),
                          decoration: InputDecoration(
                            labelText: l10n.aiWorkspace,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      AppActionButton(
                        label: l10n.aiTestConnection,
                        icon: Icons.wifi_tethering,
                        appearance: AppActionButtonAppearance.primary,
                        fullWidth: true,
                        loading: _isTestingConnection,
                        onPressed: _isBusy || !_isApiKeyLoaded
                            ? null
                            : _testConnection,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(height: 1),
                      ),
                      Text(
                        l10n.chatDiarySettingsSection,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 8),
                      Material(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _promptTile(ChatDiaryPromptPurpose.conversation),
                            const Divider(height: 1, indent: 52, endIndent: 12),
                            _promptTile(ChatDiaryPromptPurpose.generation),
                          ],
                        ),
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelConnectionTest();
    _invalidateModels();
    _credentials.clear();
    _modelFocusNode.dispose();
    for (final controller in [
      _apiKeyController,
      _baseUrlController,
      _workspaceIdController,
      _modelController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
