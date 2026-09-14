import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/application/onboarding/onboarding_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';

typedef _IntroBullet = ({IconData icon, String text});
typedef _IntroPage = ({String title, List<_IntroBullet> bullets});

List<_IntroPage> _onboardingIntroPages(AppLocalizations l10n) {
  return <_IntroPage>[
    (
      title: l10n.onboardingIntroPage1Title,
      bullets: <_IntroBullet>[
        (icon: Icons.lock_rounded, text: l10n.onboardingIntroPage1Item0),
        (
          icon: Icons.no_accounts_outlined,
          text: l10n.onboardingIntroPage1Item1,
        ),
        (icon: Icons.fingerprint_rounded, text: l10n.onboardingIntroPage1Item2),
      ],
    ),
    (
      title: l10n.onboardingIntroPage2Title,
      bullets: <_IntroBullet>[
        (icon: Icons.edit_note_rounded, text: l10n.onboardingIntroPage2Item0),
        (icon: Icons.checklist_rounded, text: l10n.onboardingIntroPage2Item1),
        (icon: Icons.attach_file_rounded, text: l10n.onboardingIntroPage2Item2),
      ],
    ),
    (
      title: l10n.onboardingIntroPage3Title,
      bullets: <_IntroBullet>[
        (icon: Icons.sell_outlined, text: l10n.onboardingIntroPage3Item0),
        (icon: Icons.badge_outlined, text: l10n.onboardingIntroPage3Item1),
        (icon: Icons.search_rounded, text: l10n.onboardingIntroPage3Item2),
        (icon: Icons.explore_outlined, text: l10n.onboardingIntroPage3Item3),
      ],
    ),
    (
      title: l10n.onboardingIntroPage4Title,
      bullets: <_IntroBullet>[
        (icon: Icons.vpn_key_outlined, text: l10n.onboardingIntroPage4Item0),
        (icon: Icons.devices_outlined, text: l10n.onboardingIntroPage4Item1),
        (
          icon: Icons.warning_amber_rounded,
          text: l10n.onboardingIntroPage4Item2,
        ),
      ],
    ),
    (
      title: l10n.onboardingIntroPage5Title,
      bullets: <_IntroBullet>[
        (icon: Icons.folder_zip_outlined, text: l10n.onboardingIntroPage5Item0),
        (icon: Icons.cloud_sync_outlined, text: l10n.onboardingIntroPage5Item1),
        (
          icon: Icons.file_download_outlined,
          text: l10n.onboardingIntroPage5Item2,
        ),
        (
          icon: Icons.file_upload_outlined,
          text: l10n.onboardingIntroPage5Item3,
        ),
      ],
    ),
  ];
}

Future<void> showOnboardingIntroDialog(BuildContext context) {
  return showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const OnboardingIntroDialog(),
  );
}

class OnboardingIntroDialog extends ConsumerStatefulWidget {
  const OnboardingIntroDialog({super.key});

  @override
  ConsumerState<OnboardingIntroDialog> createState() =>
      _OnboardingIntroDialogState();
}

class _OnboardingIntroDialogState extends ConsumerState<OnboardingIntroDialog> {
  final PageController _pageController = PageController();
  int _page = 0;
  bool _allowPop = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int page) {
    return _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _complete() async {
    await ref.read(onboardingIntroVersionProvider.notifier).markCompleted();
    if (!mounted) {
      return;
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<_IntroPage> pages = _onboardingIntroPages(l10n);
    final int pageCount = pages.length;
    final _IntroPage current = pages[_page];
    final bool isLastPage = _page >= pageCount - 1;
    final double maxContentHeight = MediaQuery.sizeOf(context).height * 0.52;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || _page == 0) {
          return;
        }
        unawaited(_goToPage(_page - 1));
      },
      child: AppDialogShell(
        title: current.title,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Align(
              alignment: Alignment.centerRight,
              child: _OnboardingLanguageToggle(),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxContentHeight),
              child: Stack(
                children: <Widget>[
                  ExcludeSemantics(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0,
                        child: _OnboardingPagePanel(page: current),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pageCount,
                      onPageChanged: (int index) =>
                          setState(() => _page = index),
                      itemBuilder: (BuildContext context, int index) =>
                          SingleChildScrollView(
                            child: _OnboardingPagePanel(page: pages[index]),
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SmoothPageIndicator(
              controller: _pageController,
              count: pageCount,
              effect: WormEffect(
                dotHeight: 8,
                dotWidth: 8,
                spacing: 8,
                activeDotColor: colors.primary,
                dotColor: colors.outlineVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (_page > 0)
            TextButton(
              onPressed: () => unawaited(_goToPage(_page - 1)),
              child: Text(l10n.onboardingIntroBack),
            ),
          FilledButton(
            onPressed: () {
              if (isLastPage) {
                unawaited(_complete());
                return;
              }
              unawaited(_goToPage(_page + 1));
            },
            child: Text(
              isLastPage
                  ? l10n.onboardingIntroGetStarted
                  : l10n.onboardingIntroNext,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPagePanel extends StatelessWidget {
  const _OnboardingPagePanel({required this.page});

  final _IntroPage page;

  @override
  Widget build(BuildContext context) => AppInsetPanel(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < page.bullets.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 16),
          _OnboardingBulletRow(bullet: page.bullets[i]),
        ],
      ],
    ),
  );
}

class _OnboardingBulletRow extends StatelessWidget {
  const _OnboardingBulletRow({required this.bullet});

  final _IntroBullet bullet;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(bullet.icon, size: 22, color: colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            bullet.text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingLanguageToggle extends ConsumerWidget {
  const _OnboardingLanguageToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage selected = watchPersonalizationPreferences(ref).locale;
    final PersonalizationPreferencesController controller = ref.read(
      personalizationPreferencesProvider.notifier,
    );
    final AppColors colors = context.appColors;

    return Tooltip(
      message: context.l10n.onboardingIntroLanguageToggleTooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.fromBorderSide(colors.outlineBorder(opacity: 0.28)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _LanguageSegment(
                label: context.l10n.onboardingIntroLanguageZhShort,
                selected: selected == AppLanguage.zh,
                onTap: () => unawaited(controller.setLocale(AppLanguage.zh)),
              ),
              _LanguageSegment(
                label: context.l10n.onboardingIntroLanguageEnShort,
                selected: selected == AppLanguage.en,
                onTap: () => unawaited(controller.setLocale(AppLanguage.en)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageSegment extends StatelessWidget {
  const _LanguageSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}
