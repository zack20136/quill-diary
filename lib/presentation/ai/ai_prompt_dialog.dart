import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/app_lifecycle.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_section.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_option_field.dart';

typedef AiPromptVariant = ({
  String Function(AppLocalizations) label,
  String Function(AppLanguage) prompt,
});

class AiPromptEdit {
  const AiPromptEdit(this.customText);
  final String? customText;
}

Future<AiPromptEdit?> showAiPromptDialog(
  BuildContext context, {
  required String Function(AppLocalizations l10n) title,
  required String Function(AppLanguage language) defaultPrompt,
  required Key fieldKey,
  String Function(AppLocalizations l10n)? help,
  String? customText,
  bool readOnly = false,
  List<AiPromptVariant> variants = const [],
}) => showAppDialog<AiPromptEdit>(
  context: context,
  builder: (_) => AiPromptDialog(
    title: title,
    help: help,
    defaultPrompt: defaultPrompt,
    fieldKey: fieldKey,
    customText: customText,
    readOnly: readOnly,
    variants: variants,
  ),
);

class AiPromptDialog extends StatefulWidget {
  const AiPromptDialog({
    super.key,
    required this.title,
    required this.defaultPrompt,
    required this.fieldKey,
    this.help,
    this.customText,
    this.readOnly = false,
    this.variants = const [],
  });

  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n)? help;
  final String Function(AppLanguage language) defaultPrompt;
  final Key fieldKey;
  final String? customText;
  final bool readOnly;
  final List<AiPromptVariant> variants;

  @override
  State<AiPromptDialog> createState() => _AiPromptDialogState();
}

class _AiPromptDialogState extends State<AiPromptDialog>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _headerScroll = ScrollController();
  late bool _custom = widget.customText != null;
  String? _locale;
  bool _invalid = false, _obscured = false;
  int _variant = 0;

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

  String _defaultPrompt() {
    final language = context.l10n.localeName == 'en'
        ? AppLanguage.en
        : AppLanguage.zh;
    if (widget.variants.isNotEmpty) {
      return widget.variants[_variant].prompt(language);
    }
    return widget.defaultPrompt(language);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialogShell(
      fillHeight: true,
      scrollbarInContentMargin: !_obscured,
      title: widget.title(l10n),
      content: _obscured
          ? Center(
              child: Semantics(
                label: l10n.aiContentHidden,
                child: const Icon(Icons.lock_outline),
              ),
            )
          : _promptContent(l10n),
      leading: widget.readOnly ? null : _restoreButton(l10n),
      actions: _actions(l10n),
    );
  }

  Widget _promptContent(AppLocalizations l10n) {
    const gap = 12.0;
    final options = <Widget>[
      if (widget.help?.call(l10n) case final help?)
        Text(help, style: Theme.of(context).textTheme.bodyMedium),
      if (!widget.readOnly && _custom)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => showAiPromptDialog(
              context,
              title: widget.title,
              defaultPrompt: widget.defaultPrompt,
              fieldKey: const ValueKey('prompt-built-in-preview'),
              readOnly: true,
            ),
            child: Text(l10n.aiPromptViewBuiltIn),
          ),
        ),
      if (widget.variants.isNotEmpty)
        AppOptionField<int>(
          label: l10n.aiPromptPreviewVariant,
          value: _variant,
          options: [
            for (final (index, variant) in widget.variants.indexed)
              (index, variant.label(l10n)),
          ],
          onChanged: (index) => setState(() {
            _variant = index;
            _controller.text = _defaultPrompt();
            if (_scroll.hasClients) _scroll.jumpTo(0);
          }),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          if (_invalid || options.isNotEmpty)
            ConstrainedBox(
              // 鍵盤開啟時保留至少一行輸入空間。
              constraints: BoxConstraints(
                maxHeight:
                    (constraints.maxHeight -
                            MediaQuery.textScalerOf(context).scale(40) -
                            gap)
                        .clamp(0, double.infinity),
              ),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  controller: _headerScroll,
                  padding: const EdgeInsets.only(
                    right: AppDialogInsets.horizontal,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: gap,
                    children: [
                      if (_invalid)
                        AppFeedbackBanner(
                          message: l10n.aiPromptRequired,
                          tone: AppFeedbackTone.error,
                          outlined: true,
                        ),
                      if (options.isNotEmpty)
                        AppDialogSection(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: gap,
                            children: options,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: AppScrollbar(
              controller: _scroll,
              track: AppScrollbarTrack.frame,
              placement: AppScrollbarPlacement.gutter,
              gutterWidth: AppDialogInsets.horizontal,
              child: TextField(
                key: widget.fieldKey,
                controller: _controller,
                scrollController: _scroll,
                expands: true,
                minLines: null,
                maxLines: null,
                readOnly: widget.readOnly,
                textAlignVertical: TextAlignVertical.top,
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
        ],
      ),
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
          if (_headerScroll.hasClients) _headerScroll.jumpTo(0);
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
    _scroll.dispose();
    _headerScroll.dispose();
    _controller.dispose();
    super.dispose();
  }
}
