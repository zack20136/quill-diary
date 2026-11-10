import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
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
    setState(() => _obscured = state != AppLifecycleState.resumed);
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
                          contentPadding: const EdgeInsets.all(12),
                          errorText: _invalid ? l10n.aiPromptRequired : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: _actions(l10n),
    );
  }

  List<Widget> _actions(AppLocalizations l10n) {
    final cancel = TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(
        widget.readOnly ? l10n.commonActionClose : l10n.commonActionCancel,
      ),
    );
    if (widget.readOnly) return [cancel];
    final restore = TextButton(
      onPressed: _controller.text == _defaultPrompt()
          ? null
          : () => setState(() {
              _custom = false;
              _invalid = false;
              _controller.text = _defaultPrompt();
            }),
      child: Text(l10n.aiPromptRestoreDefault),
    );
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
    return [
      SizedBox(
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final style = Theme.of(context).textTheme.labelLarge;
            final scaler = MediaQuery.textScalerOf(context);
            double buttonWidth(String label) {
              final painter = TextPainter(
                text: TextSpan(text: label, style: style),
                textDirection: Directionality.of(context),
                textScaler: scaler,
              )..layout();
              final width = painter.width + 48;
              painter.dispose();
              return width < 64 ? 64 : width;
            }

            final endActions = OverflowBar(
              spacing: 8,
              overflowSpacing: 8,
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              children: [cancel, apply],
            );
            final endWidth =
                buttonWidth(l10n.commonActionCancel) +
                buttonWidth(l10n.aiPromptApply) +
                8;
            if (buttonWidth(l10n.aiPromptRestoreDefault) + 12 + endWidth <=
                constraints.maxWidth) {
              return Row(
                children: [
                  restore,
                  const Spacer(),
                  SizedBox(width: endWidth, child: endActions),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: restore),
                const SizedBox(height: 8),
                endActions,
              ],
            );
          },
        ),
      ),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
