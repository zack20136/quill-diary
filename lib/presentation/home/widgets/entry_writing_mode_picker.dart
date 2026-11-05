import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/home/home_layout.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/app_choice_card.dart';
import 'package:quill_diary/shared/presentation/widgets/app_layout.dart';

enum EntryWritingMode { direct, chat }

Future<EntryWritingMode?> showEntryWritingModePicker(
  BuildContext context, {
  required UnlockedVaultSession session,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final wide = MediaQuery.sizeOf(context).width >= HomeLayout.tabWideBreakpoint;
  final colors = Theme.of(context).colorScheme;
  final content = _EntryWritingModePicker(session: session, wide: wide);
  if (wide) {
    return showDialog<EntryWritingMode>(
      context: context,
      builder: (_) => Center(
        child: AppResponsiveWidth(
          maxWidth: 480,
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            backgroundColor: colors.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PageStyle.radiusCard),
            ),
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<EntryWritingMode>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: colors.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(PageStyle.radiusCard),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => content,
  );
}

class _EntryWritingModePicker extends ConsumerStatefulWidget {
  const _EntryWritingModePicker({required this.session, required this.wide});
  final UnlockedVaultSession session;
  final bool wide;

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope<EntryWritingMode>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _completed = true;
      },
      child: LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.8),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, widget.wide ? 16 : 12, 20, 20),
              child: Column(
                key: const ValueKey('entry-writing-mode-picker'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.wide) ...[
                    Center(
                      child: Container(
                        key: const ValueKey('entry-writing-mode-handle'),
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.onSurfaceVariant,
                          borderRadius: BorderRadius.circular(
                            PageStyle.radiusPanel,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            l10n.homeTooltipNewEntry,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.commonCloseTooltip,
                        onPressed: () => _finish(null),
                        style: IconButton.styleFrom(
                          foregroundColor: colors.onSurface,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
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
                  ),
                ],
              ),
            ),
          ),
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
