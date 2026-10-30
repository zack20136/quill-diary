import 'dart:async' show unawaited;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/home_layout.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';

class FirstLaunchHomePane extends StatelessWidget {
  const FirstLaunchHomePane({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: HomeLayout.bodyPadding,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.firstLaunchHomeTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  _FirstLaunchActionCard(
                    icon: Icons.key_outlined,
                    title: l10n.firstLaunchCreateVaultTitle,
                    message: l10n.firstLaunchCreateVaultMessage,
                    onTap: () => unawaited(
                      context.push(
                        AppRoutes.settingsLocation(
                          focus: SettingsFocusTarget.recoveryKey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FirstLaunchActionCard(
                    icon: Icons.unarchive_outlined,
                    title: l10n.firstLaunchTransferTitle,
                    message: l10n.firstLaunchTransferMessage,
                    onTap: () => unawaited(
                      context.push(
                        AppRoutes.settingsLocation(
                          focus: SettingsFocusTarget.externalRestore,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FirstLaunchActionCard extends StatelessWidget {
  const _FirstLaunchActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                icon,
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
