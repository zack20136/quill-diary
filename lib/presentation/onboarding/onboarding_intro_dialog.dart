import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/onboarding/onboarding_providers.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_section.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

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
        (icon: Icons.forum_outlined, text: l10n.onboardingIntroPage2Item1),
        (
          icon: Icons.outbound_rounded,
          text: l10n.onboardingIntroPage2Item2(
            l10n.chatDiarySend,
            l10n.chatDiaryGenerateDiary,
            l10n.organizationGenerate,
          ),
        ),
      ],
    ),
    (
      title: l10n.onboardingIntroPage3Title,
      bullets: <_IntroBullet>[
        (
          icon: Icons.sell_outlined,
          text: l10n.onboardingIntroPage3Item0(l10n.homeNavTags),
        ),
        (
          icon: Icons.badge_outlined,
          text: l10n.onboardingIntroPage3Item1(l10n.homeNavPeople),
        ),
        (
          icon: Icons.explore_outlined,
          text: l10n.onboardingIntroPage3Item2(l10n.homeNavCalendar),
        ),
      ],
    ),
    (
      title: l10n.onboardingIntroPage4Title,
      bullets: <_IntroBullet>[
        (icon: Icons.folder_zip_outlined, text: l10n.onboardingIntroPage4Item0),
        (
          icon: Icons.file_download_outlined,
          text: l10n.onboardingIntroPage4Item1,
        ),
        (
          icon: Icons.file_upload_outlined,
          text: l10n.onboardingIntroPage4Item2,
        ),
      ],
    ),
    (
      title: l10n.onboardingIntroPage5Title,
      bullets: <_IntroBullet>[
        (icon: Icons.vpn_key_outlined, text: l10n.onboardingIntroPage5Item0),
        (icon: Icons.devices_outlined, text: l10n.onboardingIntroPage5Item1),
        (
          icon: Icons.warning_amber_rounded,
          text: l10n.onboardingIntroPage5Item2,
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
  bool _completing = false;

  Widget _keepSpace({required bool visible, required Widget child}) =>
      Visibility(
        visible: visible,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: child,
      );

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
    if (_completing) return;
    _completing = true;
    try {
      await ref.read(hasSeenOnboardingIntroProvider.notifier).markCompleted();
      if (mounted) Navigator.of(context).pop();
    } finally {
      _completing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<_IntroPage> pages = _onboardingIntroPages(l10n);
    final bool isLastPage = _page == pages.length - 1;
    final double textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final bool languageBelowTitle =
        MediaQuery.sizeOf(context).width / textScale < 300;
    const languageToggle = _OnboardingLanguageToggle();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || _page == 0) {
          return;
        }
        unawaited(_goToPage(_page - 1));
      },
      child: AppDialogShell(
        title: pages[_page].title,
        sizingTitles: [for (final page in pages) page.title],
        titleTrailing: languageBelowTitle ? null : languageToggle,
        showClose: false,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (languageBelowTitle)
              const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: languageToggle,
                ),
              ),
            Flexible(
              child: Stack(
                children: [
                  _keepSpace(
                    visible: false,
                    child: SingleChildScrollView(
                      primary: false,
                      child: Stack(
                        children: [
                          for (final page in pages)
                            _OnboardingPagePanel(page: page),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pages.length,
                      onPageChanged: (int index) =>
                          setState(() => _page = index),
                      itemBuilder: (BuildContext context, int index) =>
                          SingleChildScrollView(
                            primary: false,
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
              count: pages.length,
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
        leading: _keepSpace(
          visible: !isLastPage,
          child: TextButton(
            onPressed: _complete,
            child: Text(l10n.onboardingIntroSkip),
          ),
        ),
        actions: <Widget>[
          _keepSpace(
            visible: _page > 0,
            child: TextButton(
              onPressed: () => unawaited(_goToPage(_page - 1)),
              child: Text(l10n.onboardingIntroBack),
            ),
          ),
          FilledButton(
            onPressed: isLastPage
                ? _complete
                : () => unawaited(_goToPage(_page + 1)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _keepSpace(
                  visible: !isLastPage,
                  child: Text(l10n.onboardingIntroNext),
                ),
                _keepSpace(
                  visible: isLastPage,
                  child: Text(l10n.onboardingIntroGetStarted),
                ),
              ],
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
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 10,
    children: <Widget>[
      for (final bullet in page.bullets)
        AppDialogSection(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: _OnboardingBulletRow(bullet: bullet),
        ),
    ],
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
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              bullet.icon,
              size: 20,
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
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
