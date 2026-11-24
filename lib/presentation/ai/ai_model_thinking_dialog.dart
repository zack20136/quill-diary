import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_model_thinking_override.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_connection_labels.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_section.dart';
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
  final _validationBanner = GlobalKey();
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
    _invalidSelection = !_enabled.contains(_default);
    for (final level in _enabled) {
      try {
        final fields = parseThinkingObject(_controllers[level]!.text);
        if (fields.keys.any(protectedAiRequestFields.contains)) {
          _errors[level] = l10n.aiThinkingProtectedFields;
        }
      } on FormatException {
        _errors[level] = l10n.aiThinkingJsonInvalid;
      }
    }
    if (_invalidSelection || _errors.isNotEmpty) {
      setState(() {});
      if (_invalidSelection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final banner = _validationBanner.currentContext;
          if (banner != null) unawaited(Scrollable.ensureVisible(banner));
        });
      }
      return;
    }
    Navigator.pop(context, AiThinkingEditResult(_parse()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final editable = _mode == 'custom';
    final formatHint = switch (_mode) {
      'inherit' => l10n.aiThinkingFormatHint,
      'omit' => l10n.aiThinkingOmitHint,
      _ => l10n.aiThinkingCustomHint,
    };
    final preview = _previewFields();
    return AppDialogShell(
      title: l10n.aiThinkingSettingsTitle,
      content: AppScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            if (editable && _invalidSelection && !_enabled.contains(_default))
              AppFeedbackBanner(
                key: _validationBanner,
                message: l10n.aiThinkingSelectionRequired,
                tone: AppFeedbackTone.error,
                outlined: true,
              ),
            AppDialogSection(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Icon(
                        Icons.memory_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      Expanded(
                        child: Text(widget.model, style: text.titleSmall),
                      ),
                    ],
                  ),
                  AppOptionField<String>(
                    key: const ValueKey('thinking-format'),
                    label: l10n.aiThinkingFormat,
                    value: _mode,
                    options: [
                      ('inherit', l10n.aiThinkingInherit),
                      ('omit', l10n.aiThinkingOmit),
                      ('custom', l10n.aiThinkingCustom),
                    ],
                    onChanged: (mode) => setState(() => _mode = mode),
                  ),
                  Text(formatHint, style: text.bodySmall),
                ],
              ),
            ),
            AppDialogSection(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Text(l10n.aiThinkingPreview, style: text.titleSmall),
                  if (_default case final level? when editable)
                    Text(
                      l10n.aiThinkingPreviewLevel(aiThinkingLabel(l10n, level)),
                      style: text.bodySmall,
                    ),
                  if (preview == null)
                    Text(l10n.aiThinkingPreviewInvalid, style: text.bodyMedium)
                  else if (preview.isEmpty)
                    Text(l10n.aiThinkingPreviewEmpty, style: text.bodyMedium)
                  else
                    SelectableText(
                      const JsonEncoder.withIndent('  ').convert(preview),
                      style: text.bodyMedium?.copyWith(fontFamily: 'monospace'),
                    ),
                ],
              ),
            ),
            if (editable) ...[
              AppFeedbackBanner(
                message: l10n.aiThinkingAdvancedOverrideHint,
                tone: AppFeedbackTone.warning,
              ),
              _advancedSettings(l10n, text),
            ],
          ],
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

  Map<String, Object?>? _previewFields() {
    if (_mode == 'inherit') return thinkingRequestFields(_inheritedConfig);
    if (_mode == 'omit') return const {};
    try {
      return _parse().levels[_default];
    } on FormatException {
      return null;
    }
  }

  Widget _advancedSettings(AppLocalizations l10n, TextTheme text) =>
      AppDialogSection(
        padding: const EdgeInsets.all(12),
        child: Column(
          key: const ValueKey('thinking-advanced'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.aiThinkingAdvanced, style: text.titleSmall),
            const SizedBox(height: 8),
            Text(l10n.aiThinkingAdvancedHint, style: text.bodySmall),
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
            for (final level in AiThinkingLevel.values) ...[
              if (level != AiThinkingLevel.values.first)
                const Divider(height: 16),
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
                    maxLines: null,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: text.bodyMedium?.copyWith(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: l10n.aiThinkingJsonLabel(
                        aiThinkingLabel(l10n, level),
                      ),
                      errorText: _errors[level],
                      errorMaxLines: 6,
                    ),
                    onChanged: (_) => setState(() => _errors.remove(level)),
                  ),
                ),
            ],
          ],
        ),
      );
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
