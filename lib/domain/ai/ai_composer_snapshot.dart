import 'package:quill_diary/domain/ai/private_text.dart';

/// 未送出或編輯前的輸入。圖片只存在聊天；空的 imageIds 不寫入。
class AiComposerSnapshot {
  AiComposerSnapshot({
    required this.text,
    required this.ranges,
    required this.imageIds,
    this.revealed = const [],
  });

  final String text;
  final List<PrivateTextRange> ranges;
  final List<PrivateTextRange> revealed;
  final List<String> imageIds;

  Map<String, Object?> toJson() => {
    'text': text,
    'ranges': privateRangesToJson(ranges),
    if (revealed.isNotEmpty) 'revealed': privateRangesToJson(revealed),
    if (imageIds.isNotEmpty) 'image_ids': imageIds,
  };

  factory AiComposerSnapshot.fromJson(Map<String, dynamic> json) =>
      AiComposerSnapshot(
        text: json['text'] as String,
        ranges: privateRangesFromJson(json['ranges'] as List),
        revealed: privateRangesFromJson(json['revealed']),
        imageIds: (json['image_ids'] as List? ?? const <String>[])
            .cast<String>(),
      );
}
