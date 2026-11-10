import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/widgets/adaptive_panel.dart';
import 'package:quill_diary/shared/presentation/widgets/app_choice_card.dart';

enum EntryWritingMode { direct, chat }

Future<EntryWritingMode?> showEntryWritingModePicker(
  BuildContext context, {
  required UnlockedVaultSession session,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final content = _EntryWritingModePicker(session: session);
  return showAdaptivePanel<EntryWritingMode>(
    context: context,
    builder: (_) => content,
  );
}

class _EntryWritingModePicker extends ConsumerStatefulWidget {
  const _EntryWritingModePicker({required this.session});
  final UnlockedVaultSession session;

  @override
  ConsumerState<_EntryWritingModePicker> createState() =>
      _EntryWritingModePickerState();
}

class _EntryWritingModePickerState
    extends ConsumerState<_EntryWritingModePicker>
    with WidgetsBindingObserver {
  bool _completed = false;

  bool get _sessionIsCurrent {
    final state = ref.read(effectiveAppSessionProvider);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return !state.isLoading &&
        !state.hasError &&
        state.value?.isUnlocked == true &&
        state.value?.session == widget.session &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(effectiveAppSessionProvider, (_, next) {
      final current = next.value;
      if (next.hasError ||
          (current != null &&
              (!current.isUnlocked || current.session != widget.session))) {
        _finish(null);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !ref.read(effectiveAppSessionProvider).isLoading &&
          !_sessionIsCurrent) {
        _finish(null);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 背景會暫停動畫，直接移除以免恢復時殘留面板。
    if (state != AppLifecycleState.resumed) _finish(null, animate: false);
  }

  void _finish(EntryWritingMode? mode, {bool animate = true}) {
    if (!mounted || _completed) return;
    final result = mode != null && _sessionIsCurrent ? mode : null;
    _completed = true;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    if (animate && route.isCurrent) {
      Navigator.of(context).pop(result);
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope<EntryWritingMode>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _completed = true;
      },
      child: AdaptiveChoicePanel(
        title: l10n.homeTooltipNewEntry,
        onClose: () => _finish(null),
        panelKey: const ValueKey('entry-writing-mode-picker'),
        handleKey: const ValueKey('entry-writing-mode-handle'),
        child: Column(
          children: [
            AppChoiceCard(
              key: const ValueKey('entry-writing-mode-direct'),
              icon: Icons.edit_note,
              title: l10n.chatDiaryWriteDirectly,
              description: l10n.entryWritingModeDirectDescription,
              onPressed: () => _finish(EntryWritingMode.direct),
            ),
            const SizedBox(height: 12),
            AppChoiceCard(
              key: const ValueKey('entry-writing-mode-chat'),
              icon: Icons.chat_bubble_outline,
              title: l10n.chatDiaryTitle,
              description: l10n.entryWritingModeChatDescription,
              onPressed: () => _finish(EntryWritingMode.chat),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
