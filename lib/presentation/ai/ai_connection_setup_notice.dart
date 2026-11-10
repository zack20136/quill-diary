import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_connection_providers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';

class AiConnectionSetupNotice extends ConsumerWidget {
  const AiConnectionSetupNotice({
    super.key,
    required this.connection,
    required this.onOpenSettings,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    // 未填寫設定時只顯示按鈕；關閉或讀取失敗才需要文字說明。
    final String? message = !aiEnabled
        ? context.l10n.aiFeaturesDisabledHint
        : ready.hasError
        ? context.l10n.aiErrorSettings
        : null;
    return Padding(
      padding: padding,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (message != null)
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          AppActionButton(
            label: context.l10n.aiOpenSettings,
            icon: Icons.tune_rounded,
            appearance: AppActionButtonAppearance.tonal,
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}
