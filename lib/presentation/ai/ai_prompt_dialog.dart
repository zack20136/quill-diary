import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/app_lifecycle.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
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
  bool readOnly = false,
}) => showAppDialog<AiPromptEdit>(
  context: context,
  builder: (_) => AiPromptDialog(
    title: title,
    help: help,
    defaultPrompt: defaultPrompt,
    fieldKey: fieldKey,
    customText: customText,
    readOnly: readOnly,
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
    this.readOnly = false,
  });

  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) help;
  final String Function(AppLanguage language) defaultPrompt;
  final Key fieldKey;
  final String? customText;
  final bool readOnly;

  @override
  State<AiPromptDialog> createState() => _AiPromptDialogState();
}

class _AiPromptDialogState extends State<AiPromptDialog>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
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
    if (appLifecycleIsBackground(state)) {
      setState(() => _obscured = true);
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _obscured = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeName = context.l10n.localeName;
    if (_locale == localeName) return;
    _locale = localeName;
    if (!_custom) _controller.text = _defaultPrompt();
    _custom = _controller.text != _defaultPrompt();
  }

  String _defaultPrompt() => widget.defaultPrompt(
    context.l10n.localeName == 'en' ? AppLanguage.en : AppLanguage.zh,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final height =
        (MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom -
                240)
            .clamp(140.0, 680.0);
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
                    child: AppScrollbar(
                      controller: _scrollController,
                      track: AppScrollbarTrack.frame,
                      child: TextField(
                        key: widget.fieldKey,
                        controller: _controller,
                        scrollController: _scrollController,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        readOnly: widget.readOnly,
                        keyboardType: TextInputType.multiline,
                        onChanged: widget.readOnly
                            ? null
                            : (_) => setState(() {
                                _custom = _controller.text != _defaultPrompt();
                                _invalid = false;
                              }),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          enabledBorder: _invalid ? _errorBorder(1) : null,
                          focusedBorder: _invalid ? _errorBorder(2) : null,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ),
                  if (_invalid) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.aiPromptRequired,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
      ),
      leading: widget.readOnly ? null : _restoreButton(l10n),
      actions: _actions(l10n),
    );
  }

  OutlineInputBorder _errorBorder(double width) => OutlineInputBorder(
    borderSide: BorderSide(
      color: Theme.of(context).colorScheme.error,
      width: width,
    ),
  );

  Widget _restoreButton(AppLocalizations l10n) => TextButton(
    onPressed: _controller.text == _defaultPrompt()
        ? null
        : () => setState(() {
            _custom = false;
            _invalid = false;
            _controller.text = _defaultPrompt();
          }),
    child: Text(l10n.aiPromptRestoreDefault),
  );

  List<Widget> _actions(AppLocalizations l10n) {
    final cancel = TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(
        widget.readOnly ? l10n.commonActionClose : l10n.commonActionCancel,
      ),
    );
    if (widget.readOnly) return [cancel];
    final apply = FilledButton(
      onPressed: () {
        if (_controller.text.trim().isEmpty) {
          setState(() => _invalid = true);
          return;
        }
        Navigator.pop(
          context,
          AiPromptEdit(
            _controller.text == _defaultPrompt() ? null : _controller.text,
          ),
        );
      },
      child: Text(l10n.aiPromptApply),
    );
    return [cancel, apply];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
