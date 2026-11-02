import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_model_thinking_override.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_labels.dart';
import 'package:quill_diary/presentation/ai/ai_settings_theme.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_option_field.dart';

class AiThinkingEditResult {
  const AiThinkingEditResult(this.override);
  final AiModelThinkingOverride? override;
}

Future<AiThinkingEditResult?> showAiModelThinkingDialog(
  BuildContext context,
  AiConnectionConfig config,
  String model,
) => showAppDialog<AiThinkingEditResult>(
  context: context,
  builder: (_) => _AiModelThinkingDialog(config: config, model: model),
);

class _AiModelThinkingDialog extends StatefulWidget {
  const _AiModelThinkingDialog({required this.config, required this.model});
  final AiConnectionConfig config;
  final String model;

  @override
  State<_AiModelThinkingDialog> createState() => _AiModelThinkingDialogState();
}

class _AiModelThinkingDialogState extends State<_AiModelThinkingDialog> {
  final _controllers = {
    for (final level in AiThinkingLevel.values) level: TextEditingController(),
  };
  final _enabled = <AiThinkingLevel>{};
  final _errors = <AiThinkingLevel, String>{};
  String _mode = 'inherit';
  AiThinkingLevel? _default;
  bool _invalidSelection = false;

  @override
  void initState() {
    super.initState();
    final override = widget.config.thinkingOverrides[widget.model];
    _mode = override == null
        ? 'inherit'
        : override.levels.isEmpty
        ? 'omit'
        : 'custom';
    if (override != null && override.levels.isNotEmpty) {
      _populate(override);
    } else {
      final config = _inheritedConfig;
      final levels = <AiThinkingLevel, Map<String, Object?>>{
        for (final level in thinkingChoicesFor(config, widget.model))
          level: thinkingRequestFields(
            setThinkingLevel(config, widget.model, level),
          ),
      };
      _populate(
        AiModelThinkingOverride(
          defaultLevel: levels.isEmpty ? null : resolvedThinkingLevel(config),
          levels: levels,
        ),
      );
    }
  }

  AiConnectionConfig get _inheritedConfig => widget.config.copyWith(
    model: widget.model,
    thinkingOverrides: {...widget.config.thinkingOverrides}
      ..remove(widget.model),
  );

  void _populate(AiModelThinkingOverride value) {
    _enabled
      ..clear()
      ..addAll(value.levels.keys);
    _default = value.defaultLevel;
    for (final level in AiThinkingLevel.values) {
      _controllers[level]!.text = const JsonEncoder.withIndent('  ')
          .convert(value.levels[level] ?? const {});
    }
    _errors.clear();
    _invalidSelection = false;
  }

  AiModelThinkingOverride _parse() => AiModelThinkingOverride(
    defaultLevel: _default,
    levels: {
      for (final level in AiThinkingLevel.values)
        if (_enabled.contains(level))
          level: parseThinkingObject(_controllers[level]!.text),
    },
  );

  void _apply() {
    if (_mode == 'inherit' || _mode == 'omit') {
      Navigator.pop(
        context,
        AiThinkingEditResult(
          _mode == 'inherit' ? null : AiModelThinkingOverride.omit(),
        ),
      );
      return;
    }
    final l10n = context.l10n;
    _errors.clear();
    _invalidSelection = _enabled.isEmpty || !_enabled.contains(_default);
    for (final level in _enabled) {
      try {
        final fields = parseThinkingObject(_controllers[level]!.text);
        if (fields.keys.any(protectedAiRequestFields.contains)) {
          _errors[level] = l10n.aiThinkingProtectedFields;
        }
      } on Object {
        _errors[level] = l10n.aiThinkingJsonInvalid;
      }
    }
    if (_invalidSelection || _errors.isNotEmpty) {
      setState(() {});
      return;
    }
    Navigator.pop(context, AiThinkingEditResult(_parse()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editable = _mode != 'inherit' && _mode != 'omit';
    String preview = l10n.aiThinkingPreviewInvalid;
    if (_mode == 'inherit') {
      preview = const JsonEncoder.withIndent('  ')
          .convert(thinkingRequestFields(_inheritedConfig));
    } else if (_mode == 'omit') {
      preview = '{}';
    } else {
      try {
        preview = const JsonEncoder.withIndent('  ')
            .convert(_parse().levels[_default] ?? const {});
      } on Object {
        /* 輸入途中保留內容，套用時才顯示欄位錯誤。 */
      }
    }
    return AiSettingsTheme(
      child: AppDialogShell(
        title: l10n.aiThinkingSettingsTitle,
        content: SizedBox(
          width: 560,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height - 240).clamp(
                120,
                640,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.model,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  AppOptionField<String>(
                    key: const ValueKey('thinking-format'),
                    label: l10n.aiThinkingFormat,
                    value: _mode,
                    options: [
                      ('omit', l10n.aiThinkingOmit),
                      ('inherit', l10n.aiThinkingInherit),
                      ('custom', l10n.aiThinkingCustom),
                    ],
                    onChanged: (mode) => setState(() => _mode = mode),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.aiThinkingFormatHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (editable) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(l10n.aiThinkingAdvancedOverrideHint),
                    ),
                    const SizedBox(height: 12),
                    AppOptionField<AiThinkingLevel>(
                      key: const ValueKey('thinking-default'),
                      label: l10n.aiThinkingDefault,
                      value: _enabled.contains(_default) ? _default : null,
                      options: [
                        for (final level in AiThinkingLevel.values)
                          if (_enabled.contains(level))
                            (level, aiThinkingLabel(l10n, level)),
                      ],
                      onChanged: (value) => setState(() => _default = value),
                    ),
                    if (_invalidSelection)
                      Text(
                        l10n.aiThinkingSelectionRequired,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Column(
                      key: const ValueKey('thinking-advanced'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.aiThinkingAdvanced,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.aiThinkingAdvancedHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        for (final level in AiThinkingLevel.values) ...[
                          CheckboxListTile(
                            key: ValueKey('thinking-enabled-${level.name}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(aiThinkingLabel(l10n, level)),
                            value: _enabled.contains(level),
                            onChanged: (enabled) => setState(() {
                              if (enabled!) {
                                _enabled.add(level);
                              } else {
                                _enabled.remove(level);
                              }
                              if (!_enabled.contains(_default)) {
                                _default = _enabled.firstOrNull;
                              }
                            }),
                          ),
                          if (_enabled.contains(level))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextField(
                                key: ValueKey('thinking-json-${level.name}'),
                                controller: _controllers[level],
                                minLines: 2,
                                maxLines: 6,
                                autocorrect: false,
                                enableSuggestions: false,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                                decoration: InputDecoration(
                                  labelText:
                                      'JSON · ${aiThinkingLabel(l10n, level)}',
                                  errorText: _errors[level],
                                  errorMaxLines: 6,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(l10n.aiThinkingPreview),
                  const SizedBox(height: 6),
                  SelectableText(
                    preview,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
