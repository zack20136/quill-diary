import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/application/errors/ai_error_text.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_labels.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_menu_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_menu_panel.dart';

class AiChatModelPicker extends ConsumerStatefulWidget {
  const AiChatModelPicker({
    super.key,
    required this.current,
    required this.enabled,
    required this.onSelected,
  });
  final AiConnectionConfig current;
  final bool enabled;
  final Future<void> Function(ChatModelOption) onSelected;
  @override
  ConsumerState<AiChatModelPicker> createState() => _AiChatModelPickerState();
}

class _AiChatModelPickerState extends ConsumerState<AiChatModelPicker>
    with WidgetsBindingObserver {
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(AiChatModelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || !sameAiTarget(widget.current, oldWidget.current)) {
      _closeModelMenu();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _closeModelMenu();
  }

  List<ChatModelOption> _modelChoices = const [];
  bool _currentModelIsExtra = false;
  final MenuController _modelMenuController = MenuController();
  final FocusNode _modelTagFocusNode = FocusNode();
  final FocusNode _modelMenuFocusNode = FocusNode();
  int _modelMenuRequest = 0;

  void _closeModelMenu() {
    _modelMenuRequest++;
    _modelMenuController.close();
  }

  Future<void> _openModelMenu() async {
    if (_modelMenuController.isOpen) {
      _closeModelMenu();
      return;
    }
    final vaultSession = ref.read(effectiveAppSessionProvider).value?.session;
    final current = widget.current;
    if (vaultSession == null || !widget.enabled || !_foreground) return;
    final request = ++_modelMenuRequest;
    bool canOpen() =>
        mounted &&
        request == _modelMenuRequest &&
        _foreground &&
        widget.enabled &&
        sameAiTarget(widget.current, current) &&
        ref.read(effectiveAppSessionProvider).value?.session == vaultSession;
    try {
      final store = ref.read(aiSettingsStoreProvider);
      final stored = await store.read(vaultSession);
      if (!canOpen()) return;
      final apiKeys = <String, bool>{};
      for (final config in stored.connection.orderedConnections) {
        apiKeys[config.connectionId] = (await store.readApiKey(config))
            .trim()
            .isNotEmpty;
        if (!canOpen()) return;
      }
      final models = chatModelMenu(
        settings: stored.connection,
        chatConfig: current,
        hasApiKey: (config) => apiKeys[config.connectionId] ?? false,
      );
      if (models.models.isEmpty) return;
      setState(() {
        _modelChoices = models.models;
        _currentModelIsExtra = models.currentIsExtra;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (canOpen()) _modelMenuController.open();
      });
    } on Object catch (error) {
      if (mounted && canOpen()) {
        showAppFeedbackToast(
          context,
          aiErrorText(
            context.l10n,
            error is AiFailure ? error.code : AiErrorCode.storage,
          ),
          tone: AppFeedbackTone.error,
        );
      }
    }
  }

  Future<void> _selectModel(ChatModelOption choice) async {
    final session = ref.read(effectiveAppSessionProvider).value?.session;
    _closeModelMenu();
    try {
      await widget.onSelected(choice);
    } on Object catch (error) {
      if (!mounted ||
          ref.read(effectiveAppSessionProvider).value?.session != session) {
        return;
      }
      showAppFeedbackToast(
        context,
        aiErrorText(
          context.l10n,
          error is AiFailure ? error.code : AiErrorCode.storage,
        ),
        tone: AppFeedbackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    ref.listen(effectiveAppSessionProvider, (_, next) {
      if (next.value?.isUnlocked != true) _closeModelMenu();
    });
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final canSwitch = widget.enabled;
    final labelCounts = <String, int>{};
    for (final choice in _modelChoices) {
      final label = aiChatModelLabel(l10n, choice.connectionConfig);
      labelCounts.update(label, (count) => count + 1, ifAbsent: () => 1);
    }
    final menuItems = <Widget>[
      for (final choice in _modelChoices)
        Builder(
          builder: (context) {
            final selected = sameAiTarget(choice.connectionConfig, current);
            final label = aiChatModelLabel(l10n, choice.connectionConfig);
            final description =
                '${aiConnectionLabel(l10n, choice.connectionConfig)}\n${choice.connectionConfig.effectiveBaseUrl}/${choice.modelId}';
            return MenuItemButton(
              overflowAxis: Axis.vertical,
              key: ValueKey(
                'ai-model-option-${choice.connectionId}-${choice.modelId}${choice.isCurrentSnapshot ? '-current' : ''}',
              ),
              focusNode: selected ? _modelMenuFocusNode : null,
              onPressed: () => unawaited(_selectModel(choice)),
              style: appMenuItemStyle(context, selected: selected),
              trailingIcon: selected ? const Icon(Icons.check, size: 18) : null,
              child: Tooltip(
                message: description,
                excludeFromSemantics: true,
                child: Semantics(
                  label: description,
                  selected: selected,
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected && _currentModelIsExtra
                            ? '$label · ${l10n.aiModelCurrent}'
                            : label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      if (choice.connectionConfig.provider ==
                              AiProvider.custom &&
                          labelCounts[label]! > 1)
                        Text(
                          aiConnectionLabel(l10n, choice.connectionConfig),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
    ];
    return RawMenuAnchor(
      controller: _modelMenuController,
      childFocusNode: _modelTagFocusNode,
      onOpen: _modelMenuFocusNode.requestFocus,
      consumeOutsideTaps: true,
      overlayBuilder: (context, info) {
        const gap = 6.0;
        final menuWidth = (info.overlaySize.width - 48).clamp(0.0, 320.0);
        final maxHeight =
            (info.anchorRect.top - MediaQuery.paddingOf(context).top - gap - 8)
                .clamp(0.0, 320.0);
        final maxLeft = (info.overlaySize.width - menuWidth - 12).clamp(
          0.0,
          double.infinity,
        );
        return Positioned(
          left: info.anchorRect.left.clamp(0.0, maxLeft),
          bottom: info.overlaySize.height - info.anchorRect.top + gap,
          child: TapRegion(
            groupId: info.tapRegionGroupId,
            consumeOutsideTaps: true,
            onTapOutside: (_) => _closeModelMenu(),
            child: AppMenuPanel(
              key: const ValueKey('ai-model-menu'),
              width: menuWidth,
              maxHeight: maxHeight,
              children: menuItems,
            ),
          ),
        );
      },
      builder: (context, controller, child) => ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 32,
        ),
        child: Material(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: Tooltip(
            message: l10n.aiSwitchModel,
            child: InkWell(
              key: const ValueKey('ai-model-tag'),
              focusNode: _modelTagFocusNode,
              onTap: canSwitch ? () => unawaited(_openModelMenu()) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        aiChatModelLabel(l10n, current),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeModelMenu();
    _modelTagFocusNode.dispose();
    _modelMenuFocusNode.dispose();
    super.dispose();
  }
}
