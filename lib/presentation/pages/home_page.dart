import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../state/app_session_state.dart';
import '../widgets/feature_placeholder_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const AppSessionState sessionState = AppSessionState(
      status: AppLockStatus.uninitialized,
      message: '骨架階段：尚未接入 App Lock 與 Recovery 流程。',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('QuillLockDiary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '本地加密 Markdown 日記',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '目前先建立專案骨架，後續會把 diary、recovery、backup 與索引流程接進來。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Session: ${sessionState.status.name}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (sessionState.message != null) ...[
            const SizedBox(height: 4),
            Text(sessionState.message!),
          ],
          const SizedBox(height: 24),
          FeaturePlaceholderCard(
            title: '寫日記',
            description: '對應 diary/application/domain 骨架，之後會接上編輯器與儲存流程。',
            onTap: () => Navigator.of(context).pushNamed(AppRouter.editorRoute),
          ),
          const SizedBox(height: 12),
          FeaturePlaceholderCard(
            title: '資料救援',
            description: '對應 recovery/security/crypto 骨架，之後會接上 Recovery Key 流程。',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRouter.recoveryRoute),
          ),
          const SizedBox(height: 12),
          const FeaturePlaceholderCard(
            title: '備份與索引',
            description: 'database、drive、storage 目錄已預留，下一步再接 SQLite 與 .jbackup 契約。',
          ),
        ],
      ),
    );
  }
}
