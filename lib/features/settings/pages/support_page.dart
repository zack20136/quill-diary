import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/presentation/page_style.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  static const String _supportHandle = '@quill-lock-diary';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color pageBackground = PageStyle.scaffoldWash(cs);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Text('\u8d0a\u52a9\u958b\u767c'),
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            _SupportHero(
              onCopy: () async {
                await Clipboard.setData(const ClipboardData(text: _supportHandle));
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('\u5df2\u8907\u88fd\u8d0a\u52a9\u8b58\u5225\u5b57'),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const _SupportCard(
              icon: Icons.build_circle_outlined,
              title: '\u4f60\u7684\u8d0a\u52a9\u6703\u7528\u5728\u54ea\u88e1',
              body:
                  '\u6703\u512a\u5148\u6295\u5165\u5728\u96e2\u7dda\u52a0\u5bc6\u3001\u5099\u4efd\u9084\u539f\u3001\u8de8\u88dd\u7f6e\u7a69\u5b9a\u6027\u8207 UI \u7d30\u7bc0\u6574\u7406\u3002\u9019\u985e\u529f\u80fd\u958b\u767c\u548c\u6e2c\u8a66\u90fd\u6bd4\u8f03\u82b1\u6642\u9593\uff0c\u5c24\u5176\u662f\u8cc7\u6599\u5b89\u5168\u8207\u8cc7\u6599\u9077\u79fb\u76f8\u95dc\u6d41\u7a0b\u3002',
            ),
            const SizedBox(height: 16),
            const _SupportCard(
              icon: Icons.volunteer_activism_outlined,
              title: '\u76ee\u524d\u8d0a\u52a9\u65b9\u5f0f',
              body:
                  '\u76ee\u524d\u5148\u4fdd\u7559\u7ad9\u5167\u5165\u53e3\uff0c\u65b9\u4fbf\u4e4b\u5f8c\u63a5\u4e0a\u5be6\u969b\u7684\u8d0a\u52a9\u5e73\u53f0\u6216\u4ed8\u6b3e\u9023\u7d50\u3002\u82e5\u4f60\u5df2\u7d93\u6709\u56fa\u5b9a\u7684\u8d0a\u52a9\u9801\u7db2\u5740\uff0c\u53ea\u8981\u628a\u9019\u9801\u7684\u8b58\u5225\u5b57\u6216\u6309\u9215\u52d5\u4f5c\u63db\u6389\u5373\u53ef\uff0c\u4e0d\u9700\u8981\u518d\u6539\u8a2d\u5b9a\u9801\u5165\u53e3\u3002',
            ),
            const SizedBox(height: 16),
            const _SupportCard(
              icon: Icons.privacy_tip_outlined,
              title: '\u96b1\u79c1\u63d0\u9192',
              body:
                  '\u8d0a\u52a9\u9801\u672c\u8eab\u4e0d\u6703\u63a5\u89f8\u4f60\u7684\u65e5\u8a18\u5167\u5bb9\uff0c\u4e5f\u4e0d\u6703\u8b80\u53d6 vault\u3002\u82e5\u672a\u4f86\u63a5\u4e0a\u5916\u90e8\u91d1\u6d41\uff0c\u5efa\u8b70\u53ea\u5e36\u6700\u5c11\u5fc5\u8981\u8cc7\u8a0a\uff0c\u4e0d\u8981\u628a\u65e5\u8a18\u8b58\u5225\u8cc7\u6599\u3001\u5099\u4efd\u8cc7\u8a0a\u6216\u5fa9\u539f\u91d1\u9470\u5e36\u5230\u7b2c\u4e09\u65b9\u670d\u52d9\u3002',
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportHero extends StatelessWidget {
  const _SupportHero({required this.onCopy});

  final Future<void> Function() onCopy;

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
            Color.alphaBlend(cs.secondary.withValues(alpha: 0.18), cs.surface),
            Color.alphaBlend(cs.primary.withValues(alpha: 0.10), cs.surfaceContainerLow),
          ],
        ),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.favorite_rounded, color: cs.secondary, size: 30),
            const SizedBox(height: 14),
            Text(
              '\u652f\u6301\u9019\u500b App \u6301\u7e8c\u7dad\u8b77',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              '\u6211\u5148\u628a\u8d0a\u52a9\u5165\u53e3\u505a\u6210\u7368\u7acb\u9801\u9762\uff0c\u5f8c\u7e8c\u8981\u63a5 Buy Me a Coffee\u3001GitHub Sponsors \u6216\u4efb\u4f55\u4ed8\u6b3e\u9801\uff0c\u90fd\u53ea\u8981\u66ff\u63db\u9019\u88e1\u7684\u52d5\u4f5c\u5373\u53ef\u3002',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                border: Border.fromBorderSide(PageStyle.outlineSide(cs, opacity: 0.28)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        SupportPage._supportHandle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('\u8907\u88fd'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
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
        color: cs.surface,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  cs.secondary.withValues(alpha: 0.10),
                  cs.surfaceContainerLow,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: cs.secondary, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
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
