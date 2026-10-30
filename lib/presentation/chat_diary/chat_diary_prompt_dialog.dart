import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/application/chat_diary/chat_diary_prompt_resolver.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_settings.dart';

import 'package:quill_diary/domain/preferences/personalization_preferences.dart';

import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

class ChatDiaryPromptEdit {
  const ChatDiaryPromptEdit(this.customText);
  final String? customText;
}

Future<ChatDiaryPromptEdit?> showChatDiaryPromptDialog(
  BuildContext context, {
  required ChatDiaryPromptPurpose purpose,
  String? customText,
}) => showAppDialog<ChatDiaryPromptEdit>(
  context: context,
  builder: (_) =>
      ChatDiaryPromptDialog(purpose: purpose, customText: customText),
);

class ChatDiaryPromptDialog extends StatefulWidget {
  const ChatDiaryPromptDialog({
    super.key,
    required this.purpose,
    this.customText,
  });
  final ChatDiaryPromptPurpose purpose;
  final String? customText;
  @override
  State<ChatDiaryPromptDialog> createState() => _ChatDiaryPromptDialogState();
}

class _ChatDiaryPromptDialogState extends State<ChatDiaryPromptDialog>
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
    if (!_custom) {
      _controller.text = _defaultPrompt();
    }
  }

  String _defaultPrompt() => resolveChatDiaryPrompt(
    widget.purpose,
    context.l10n.localeName == 'en' ? AppLanguage.en : AppLanguage.zh,
    const ChatDiaryPromptSettings(),
  );
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = widget.purpose == ChatDiaryPromptPurpose.conversation
        ? l10n.chatDiaryConversationPrompt
        : l10n.chatDiaryGenerationPrompt;
    final height = (MediaQuery.sizeOf(context).height - 240).clamp(
      140.0,
      680.0,
    );
    return AppDialogShell(
      title: title,
      content: SizedBox(
        width: 640,
        height: height,
        child: _obscured
            ? Center(
                child: Semantics(
                  label: l10n.chatDiaryContentHidden,
                  child: const Icon(Icons.lock_outline),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.chatDiaryPromptHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      key: ValueKey(widget.purpose),
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
                        errorText: _invalid
                            ? l10n.chatDiaryPromptRequired
                            : null,
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
          child: Text(l10n.chatDiaryRestoreDefault),
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
              ChatDiaryPromptEdit(_custom ? _controller.text : null),
            );
          },
          child: Text(l10n.chatDiaryApplyPrompt),
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
