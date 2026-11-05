import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_markdown_preview.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

enum AiMessageFormat { plainText, markdown }

/// 聊天與請求預覽共用呈現，操作及狀態由呼叫端提供。
class AiMessageView extends ConsumerWidget {
  const AiMessageView({
    super.key,
    required this.text,
    required this.isUser,
    required this.format,
    this.privateRanges = const [],
    this.images = const [],
    this.bodyKey,
    this.header,
    this.bubbleFooter,
    this.footer,
  });

  final String text;
  final bool isUser;
  final AiMessageFormat format;
  final List<PrivateTextRange> privateRanges;
  final List<Widget> images;
  final Key? bodyKey;
  final Widget? header;
  final Widget? bubbleFooter;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final typography = watchPersonalizationPreferences(ref).typography;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.88,
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (header != null)
              Padding(padding: const EdgeInsets.only(bottom: 4), child: header),
            if (images.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: text.isNotEmpty ? 8 : 0),
                child: Wrap(
                  alignment: isUser ? WrapAlignment.end : WrapAlignment.start,
                  spacing: 8,
                  runSpacing: 8,
                  children: images,
                ),
              ),
            if (text.isNotEmpty || bubbleFooter != null)
              IntrinsicWidth(
                child: Container(
                  key: bodyKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? colors.primaryContainer
                        : colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (text.isNotEmpty)
                        SelectionArea(
                          child: switch (format) {
                            AiMessageFormat.plainText => PrivateText(
                              text: text,
                              ranges: privateRanges,
                              style: typography.bodyTextStyle(
                                Theme.of(context).textTheme,
                              ),
                            ),
                            AiMessageFormat.markdown => EditorMarkdownPreview(
                              markdown: text,
                              typography: typography,
                              privateRanges: privateRanges,
                            ),
                          },
                        ),
                      ?bubbleFooter,
                    ],
                  ),
                ),
              ),
            ?footer,
          ],
        ),
      ),
    );
  }
}
