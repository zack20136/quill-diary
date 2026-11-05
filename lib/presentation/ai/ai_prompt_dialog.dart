import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

class AiPromptEdit {
  const AiPromptEdit(this.customText);
  final String? customText;
}

Future<AiPromptEdit?> showAiPromptDialog(
  BuildContext context, {
  required String Function(AppLocalizations l10n) title,
  required String Function(AppLocalizations l10n) help,
  required String Function(AppLanguage language) defaultPrompt,
  required Key fieldKey,
  String? customText,
}) => showAppDialog<AiPromptEdit>(
  context: context,
  builder: (_) => AiPromptDialog(
    title: title,
    help: help,
    defaultPrompt: defaultPrompt,
    fieldKey: fieldKey,
    customText: customText,
  ),
);

class AiPromptDialog extends StatefulWidget {
  const AiPromptDialog({
    super.key,
    required this.title,
    required this.help,
    required this.defaultPrompt,
    required this.fieldKey,
    this.customText,
  });

  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) help;
  final String Function(AppLanguage language) defaultPrompt;
  final Key fieldKey;
  final String? customText;

  @override
  State<AiPromptDialog> createState() => _AiPromptDialogState();
}

class _AiPromptDialogState extends State<AiPromptDialog>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  late bool _custom = widget.customText != null;
  String? _locale;
  bool _invalid = false, _obscured = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.customText ?? '';
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _obscured = state != AppLifecycleState.resumed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeName = context.l10n.localeName;
    if (_locale == localeName) return;
    _locale = localeName;
    if (!_custom) _controller.text = _defaultPrompt();
  }

  String _defaultPrompt() => widget.defaultPrompt(
    context.l10n.localeName == 'en' ? AppLanguage.en : AppLanguage.zh,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final height = (MediaQuery.sizeOf(context).height - 240).clamp(
      140.0,
      680.0,
    );
    return AppDialogShell(
      title: widget.title(l10n),
      content: SizedBox(
        width: 640,
        height: height,
        child: _obscured
            ? Center(
                child: Semantics(
                  label: l10n.aiContentHidden,
                  child: const Icon(Icons.lock_outline),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.help(l10n),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      key: widget.fieldKey,
                      controller: _controller,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      onChanged: (_) => setState(() {
                        _custom = true;
                        _invalid = false;
                      }),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        errorText: _invalid ? l10n.aiPromptRequired : null,
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _custom = false;
            _invalid = false;
            _controller.text = _defaultPrompt();
          }),
          child: Text(l10n.aiPromptRestoreDefault),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonActionCancel),
        ),
        FilledButton(
          onPressed: () {
            if (_controller.text.trim().isEmpty) {
              setState(() => _invalid = true);
              return;
            }
            Navigator.pop(
              context,
              AiPromptEdit(_custom ? _controller.text : null),
            );
          },
          child: Text(l10n.aiPromptApply),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }
}
