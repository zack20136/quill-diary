import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';
import 'package:quill_diary/shared/presentation/private_text_spans.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

class AiPreviewTextSection extends StatefulWidget {
  static const bodyMaxHeight = 220.0;
  const AiPreviewTextSection({
    super.key,
    required this.title,
    required this.text,
    this.initiallyExpanded = false,
  });

  final String title;
  final String text;
  final bool initiallyExpanded;

  @override
  State<AiPreviewTextSection> createState() => _AiPreviewTextSectionState();
}

class _AiPreviewTextSectionState extends State<AiPreviewTextSection> {
  late bool _expanded = widget.initiallyExpanded;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.onSurface,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: AiPreviewTextSection.bodyMaxHeight,
              ),
              child: AppScrollbar(
                controller: _scrollController,
                track: AppScrollbarTrack.frame,
                trailingGutter: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(12, 0, 0, 12),
                  child: _PreviewText(widget.text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewText extends ConsumerWidget {
  const _PreviewText(this.text);

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = watchPersonalizationPreferences(ref).typography
        .bodyTextStyle(Theme.of(context).textTheme);
    return SelectionArea(
      child: PrivateText(
        text: text,
        ranges: privacyTokenRanges(text),
        style: style,
      ),
    );
  }
}
