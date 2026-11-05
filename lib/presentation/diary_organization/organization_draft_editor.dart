import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/diary_organization/diary_organization.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/private_text_spans.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

class OrganizationDraftTextController extends TextEditingController {
  OrganizationDraftTextController(
    String body,
    Map<String, String> originals, {
    Map<String, List<String>> surfaces = const {},
  }) {
    final visible = organizationVisibleText(
      body,
      originals,
      surfaces: surfaces,
    );
    _ranges = visible.ranges;
    _tokens.addAll(visible.tokens);
    text = visible.text;
  }
  final _tokens = <String>[];
  List<PrivateTextRange> _ranges = [];

  TextEditingValue protectEdit(
    TextEditingValue oldValue,
    TextEditingValue next,
  ) {
    if (oldValue.text == next.text) return next;
    var start = 0;
    while (start < oldValue.text.length &&
        start < next.text.length &&
        oldValue.text[start] == next.text[start]) {
      start++;
    }
    var end = oldValue.text.length;
    var nextEnd = next.text.length;
    while (end > start &&
        nextEnd > start &&
        oldValue.text[end - 1] == next.text[nextEnd - 1]) {
      end--;
      nextEnd--;
    }
    if (_ranges.any(
      (range) =>
          start < range.end && end > range.start ||
          start == end && start > range.start && start < range.end,
    )) {
      return oldValue;
    }
    final delta = next.text.length - oldValue.text.length;
    _ranges = [
      for (final range in _ranges)
        end <= range.start
            ? PrivateTextRange(range.start + delta, range.end + delta)
            : range,
    ];
    return next;
  }

  String get protectedBody {
    var result = text;
    for (var i = _ranges.length - 1; i >= 0; i--) {
      result = result.replaceRange(
        _ranges[i].start,
        _ranges[i].end,
        _tokens[i],
      );
    }
    return result;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => privateTextSpan(
    text: text,
    ranges: _ranges,
    highlight: privateTextHighlight(Theme.of(context).colorScheme),
    style: style,
  );
}

class OrganizationDraftEditor extends StatefulWidget {
  const OrganizationDraftEditor({
    super.key,
    required this.body,
    required this.originals,
    this.surfaces = const {},
  });
  final String body;
  final Map<String, String> originals;
  final Map<String, List<String>> surfaces;
  @override
  State<OrganizationDraftEditor> createState() =>
      _OrganizationDraftEditorState();
}

class _OrganizationDraftEditorState extends State<OrganizationDraftEditor> {
  late final OrganizationDraftTextController _controller;
  @override
  void initState() {
    super.initState();
    _controller = OrganizationDraftTextController(
      widget.body,
      widget.originals,
      surfaces: widget.surfaces,
    );
  }

  @override
  Widget build(BuildContext context) => AppDialogShell(
    title: context.l10n.organizationEditDraft,
    content: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.65,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.organizationProtectedHint),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('organization-draft-editor'),
              controller: _controller,
              inputFormatters: [
                TextInputFormatter.withFunction(_controller.protectEdit),
              ],
              minLines: 8,
              maxLines: 18,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.commonActionCancel),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _controller.protectedBody),
        child: Text(context.l10n.commonActionConfirm),
      ),
    ],
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
