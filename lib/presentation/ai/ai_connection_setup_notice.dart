import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';

class AiConnectionSetupNotice extends ConsumerWidget {
  const AiConnectionSetupNotice({
    super.key,
    required this.connection,
    required this.onOpenSettings,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final AiConnectionConfig connection;
  final VoidCallback? onOpenSettings;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(aiConnectionReadyProvider(connection));
    if (ready.value != false && !ready.hasError) {
      return const SizedBox.shrink();
    }
    final aiEnabled = ref.watch(aiEnabledProvider);
    final AppFeedbackTone tone;
    final String message;
    if (!aiEnabled) {
      tone = AppFeedbackTone.warning;
      message = context.l10n.aiFeaturesDisabledHint;
    } else if (ready.hasError) {
      tone = AppFeedbackTone.error;
      message = context.l10n.aiErrorSettings;
    } else {
      tone = AppFeedbackTone.info;
      message = context.l10n.aiConnectionSetupHint;
    }
    final ThemeData theme = Theme.of(context);
    final AppFeedbackColors colors = resolveAppFeedbackColors(context, tone);
    return Padding(
      padding: padding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    defaultAppFeedbackIcon(tone),
                    color: colors.foreground,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppActionButton(
                label: context.l10n.aiOpenSettings,
                icon: Icons.tune_rounded,
                appearance: AppActionButtonAppearance.outlined,
                onPressed: onOpenSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
