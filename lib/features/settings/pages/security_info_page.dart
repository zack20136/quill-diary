import 'package:flutter/material.dart';

import '../../../shared/presentation/page_style.dart';

class SecurityInfoPage extends StatelessWidget {
  const SecurityInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Text('安全性說明'),
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: const <Widget>[
            _HeroCard(),
            SizedBox(height: 16),
            _SecurityFlowCard(),
            SizedBox(height: 16),
            _SecurityHighlightsCard(),
            SizedBox(height: 16),
            _BackupRestoreCard(),
            SizedBox(height: 16),
            _RecoveryKeyCard(),
            SizedBox(height: 16),
            _SecurityLimitsCard(),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(cs.primary.withValues(alpha: 0.18), cs.surface),
            Color.alphaBlend(cs.tertiary.withValues(alpha: 0.10), cs.surfaceContainerLow),
          ],
        ),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.verified_user_outlined, color: cs.primary, size: 28),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '你的資料，預設先在本機加密',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              '這個 App 以離線優先為設計原則。日記內容、附件與主要中繼資料會先在裝置上完成加密，再寫入本機 vault；除非你主動備份或匯出，否則不會自動把明文日記傳到外部服務。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _FactChip(label: 'LDJ2'),
                _FactChip(label: 'AES-256-GCM'),
                _FactChip(label: 'Argon2id'),
                _FactChip(label: '本機儲存'),
                _FactChip(label: '受信任裝置'),
                _FactChip(label: '復原金鑰'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityFlowCard extends StatelessWidget {
  const _SecurityFlowCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return _SectionShell(
      title: '加密與解密圖解',
      subtitle: '把整個流程想成 5 個步驟，會比直接看技術名詞更容易理解。',
      child: Column(
        children: const <Widget>[
          _FlowStep(
            icon: Icons.edit_note_rounded,
            title: '1. 寫下內容',
            body: '你輸入的日記或附件會先在裝置端處理，還不會直接寫成可讀的明文檔案。',
          ),
          _FlowConnector(),
          _FlowStep(
            icon: Icons.vpn_key_outlined,
            title: '2. 產生隨機 file key',
            body: '每一個加密檔都會有自己的 file key，不會固定共用同一把。',
          ),
          _FlowConnector(),
          _FlowStep(
            icon: Icons.lock_rounded,
            title: '3. 用 AES-256-GCM 加密',
            body: '內容會被加密並寫成 LDJ2 格式，同時附帶完整性驗證資訊，避免被靜默竄改。',
          ),
          _FlowConnector(),
          _FlowStep(
            icon: Icons.folder_special_outlined,
            title: '4. 寫入 vault',
            body: '本機保存的是加密檔、`recovery.json` 與索引資料，不是直接可讀的日記明文。',
          ),
          _FlowConnector(),
          _FlowSplitStep(),
        ],
      ),
    );
  }
}

class _SecurityHighlightsCard extends StatelessWidget {
  const _SecurityHighlightsCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: '安全性重點',
      subtitle: '這一頁最重要的三件事：加密方式、保護範圍，以及安全機制的適用邊界。',
      child: const Column(
        children: <Widget>[
          _BulletPanel(
            icon: Icons.lock_outline_rounded,
            title: '加密方式',
            body:
                '每一筆日記或附件在寫入時，都會先產生隨機 file key，再用 AES-256-GCM 加密內容。檔案格式使用 LDJ2，真正落地保存的是加密後的資料。',
          ),
          SizedBox(height: 10),
          _BulletPanel(
            icon: Icons.security_rounded,
            title: '保護範圍',
            body:
                '資料預設存放在本機，不會自動把明文同步到外部。只要裝置與復原金鑰都保護得當，單純拿到加密檔案的人也無法直接讀出日記內容。',
          ),
          SizedBox(height: 10),
          _BulletPanel(
            icon: Icons.warning_amber_rounded,
            title: '風險邊界',
            body:
                '如果裝置已被 root、遭惡意程式控制，或攻擊者已能讀取執行中的記憶體，任何本機加密 App 的保護都會受限。這也是為什麼復原金鑰必須另外保存。',
          ),
        ],
      ),
    );
  }
}

class _BackupRestoreCard extends StatelessWidget {
  const _BackupRestoreCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: '備份與還原',
      subtitle: '備份檔保存的是加密後的 vault，不是未加密日記；還原後 App 也會重新建立本機狀態。',
      child: const Column(
        children: <Widget>[
          _InfoRow(
            label: '備份內容',
            body: '本機 `.jbackup` 與 Google Drive 備份都封裝整個已加密的 vault，不會另外保存明文日記。',
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: '還原後會發生什麼',
            body: '還原後索引資料庫會清除並重建，App 也會重新進入啟動與解鎖流程。',
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: '什麼情況可沿用本機解鎖',
            body:
                '同裝置、同 vault_id、同一代復原金鑰，且本機原本就有受信任裝置狀態時，才可能沿用本機解鎖路徑。',
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: '其他情況',
            body: '若條件不符合，就需要輸入建立該備份時保存的復原金鑰，才能完成還原後解鎖。',
          ),
        ],
      ),
    );
  }
}

class _RecoveryKeyCard extends StatelessWidget {
  const _RecoveryKeyCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: '復原金鑰',
      subtitle: '它不是可有可無的備用選項，而是整個資料保護機制裡的最終備援。',
      child: const Column(
        children: <Widget>[
          _BulletPanel(
            icon: Icons.key_rounded,
            title: '不是直接加密日記',
            body:
                '復原金鑰不會直接拿來加密日記內容，而是先透過 Argon2id 推導出 recovery wrapping key，再用來保護 `file key`。',
          ),
          SizedBox(height: 10),
          _BulletPanel(
            icon: Icons.smartphone_rounded,
            title: '不被受信任裝置取代',
            body:
                '受信任裝置解鎖只是在你自己的裝置上提供更順手的使用體驗，並不代表可以不保存復原金鑰。',
          ),
          SizedBox(height: 10),
          _BulletPanel(
            icon: Icons.history_toggle_off_rounded,
            title: '舊備份仍可能需要舊金鑰',
            body:
                '如果你後來更新過復原金鑰，較早以前做的備份，仍可能需要當時那一把舊金鑰，而不是目前的新金鑰。',
          ),
        ],
      ),
    );
  }
}

class _SecurityLimitsCard extends StatelessWidget {
  const _SecurityLimitsCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: '使用限制與提醒',
      subtitle: '這些提醒不是例外，而是實際使用時最容易誤解的地方。',
      child: const Column(
        children: <Widget>[
          _InfoRow(
            label: '備份的限制',
            body: '有備份不代表不需要復原金鑰。備份保存的是加密後的資料，還原時仍可能需要驗證。',
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: '金鑰保存原則',
            body: '復原金鑰建議離線保存，不要和手機、平板或備份檔放在同一個地方。',
          ),
          SizedBox(height: 10),
          _InfoRow(
            label: '裝置驗證的角色',
            body: '它們只影響本機受信任裝置的解鎖體驗，不等於可以取代復原金鑰。',
          ),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs, opacity: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(cs.primary.withValues(alpha: 0.12), cs.surface),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: cs.primary, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowSplitStep extends StatelessWidget {
  const _FlowSplitStep();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(cs.secondary.withValues(alpha: 0.08), cs.surfaceContainerLow),
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.hub_outlined, color: cs.secondary, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '5. 解密前先取回 file key',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '先拿到 file key，才能真正解開日記內容。通常會從下面兩條路徑擇一處理。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _FlowRouteCard(
              icon: Icons.smartphone_rounded,
              title: '受信任裝置',
              badge: '優先使用',
              body: '若目前裝置仍保有可用的本機受信任狀態，系統會先嘗試走這條路徑。',
            ),
            const SizedBox(height: 10),
            const _FlowRouteCard(
              icon: Icons.key_rounded,
              title: '復原金鑰',
              badge: '備援路徑',
              body: '若受信任裝置不可用，就改用你輸入的復原金鑰推導出 wrapping key 來解開。',
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowRouteCard extends StatelessWidget {
  const _FlowRouteCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String badge;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs, opacity: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(cs.secondary.withValues(alpha: 0.12), cs.surface),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: cs.secondary, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Text(
                            badge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowConnector extends StatelessWidget {
  const _FlowConnector();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Icon(Icons.south_rounded, color: cs.primary, size: 22),
      ),
    );
  }
}

class _BulletPanel extends StatelessWidget {
  const _BulletPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: cs.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.body,
    this.compact = false,
  });

  final String label;
  final String body;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: compact ? Colors.transparent : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 0 : 14),
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
            children: <InlineSpan>[
              TextSpan(
                text: '$label：',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: body),
            ],
          ),
        ),
      ),
    );
  }
}
