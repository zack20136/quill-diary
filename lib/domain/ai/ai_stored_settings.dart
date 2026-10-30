import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_settings.dart';

/// 會隨日記庫備份的 AI 設定。不含 API 金鑰。
class AiStoredSettings {
  const AiStoredSettings({
    this.connection = const AiConnectionSettings(),
    this.chatDiary = const ChatDiarySettings(),
  });

  final AiConnectionSettings connection;
  final ChatDiarySettings chatDiary;
}
