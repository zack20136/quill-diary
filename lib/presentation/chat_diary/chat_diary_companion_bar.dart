import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/persona/persona_providers.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/domain/persona/persona_reference.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/person_visual.dart';
import 'package:quill_diary/shared/presentation/widgets/adaptive_panel.dart';

class ChatDiaryCompanionBar extends ConsumerStatefulWidget {
  const ChatDiaryCompanionBar({
    super.key,
    required this.current,
    this.name,
    this.accentArgb,
    required this.enabled,
    required this.onSelected,
  });
  final PersonaReference? current;
  final String? name;
  final int? accentArgb;
  final bool enabled;
  final Future<void> Function(PersonaRecord?) onSelected;
  @override
  ConsumerState<ChatDiaryCompanionBar> createState() =>
      _ChatDiaryCompanionBarState();
}

class _ChatDiaryCompanionBarState extends ConsumerState<ChatDiaryCompanionBar>
    with WidgetsBindingObserver {
  Route<dynamic>? _route;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _close() {
    final route = _route;
    _route = null;
    if (route?.isActive == true) route!.navigator?.removeRoute(route);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _close();
  }

  @override
  void didUpdateWidget(ChatDiaryCompanionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _close();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _close();
    super.dispose();
  }

  Future<void> _choose() async {
    if (_opening || !widget.enabled) return;
    final session = ref.read(effectiveAppSessionProvider).value?.session;
    if (session == null) return;
    _opening = true;
    FocusManager.instance.primaryFocus?.unfocus();
    Widget content(BuildContext context) {
      _route = ModalRoute.of(context);
      return _CompanionChoices(current: widget.current);
    }

    try {
      final choice = await showAdaptivePanel<({PersonaRecord? persona})>(
        context: context,
        builder: content,
      );
      if (!mounted ||
          choice == null ||
          !widget.enabled ||
          !identical(
            ref.read(effectiveAppSessionProvider).value?.session,
            session,
          )) {
        return;
      }
      await widget.onSelected(choice.persona);
    } on Object {
      if (mounted &&
          identical(
            ref.read(effectiveAppSessionProvider).value?.session,
            session,
          )) {
        showAppFeedbackToast(
          context,
          context.l10n.personaError,
          tone: AppFeedbackTone.error,
        );
      }
    } finally {
      _route = null;
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(effectiveAppSessionProvider, (_, next) {
      if (next.value?.isUnlocked != true) _close();
    });
    final l = context.l10n;
    final people = ref.watch(peopleListProvider).value ?? [];
    final person = people
        .where((p) => p.id == widget.current?.personId)
        .firstOrNull;
    final name = widget.current == null
        ? l.personaDefaultName
        : widget.name ?? person?.name ?? l.personaRoleSubject;
    final surface = context.appColors.sectionInset;
    final (:background, foreground: accent, accent: _) = person != null
        ? personLabelColors(person, surface)
        : widget.current == null
        ? accentColorsFor(Theme.of(context).colorScheme.primary, surface)
        : personAccentColorsFor(
            personId: widget.current!.personId,
            surface: surface,
            accentArgb: widget.accentArgb,
          );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('chat-companion-bar'),
        onTap: widget.enabled ? _choose : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: background,
                foregroundColor: accent,
                child: Text(
                  personInitials(name),
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (widget.enabled) const Icon(Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanionChoices extends ConsumerWidget {
  const _CompanionChoices({required this.current});
  final PersonaReference? current;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final defaultColors = accentColorsFor(
      Theme.of(context).colorScheme.primary,
      context.appColors.sectionInset,
    );
    final personas = ref.watch(savedPersonasProvider);
    final people = ref.watch(peopleListProvider).value ?? [];
    return ConstrainedBox(
      key: const ValueKey('chat-companion-choices'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.personaChooseCompanion,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  CloseButton(onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Flexible(
              child: AppScrollView(
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        radius: 17,
                        backgroundColor: defaultColors.background,
                        foregroundColor: defaultColors.foreground,
                        child: Text(
                          personInitials(l.personaDefaultName),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: defaultColors.foreground,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      title: Text(l.personaDefaultName),
                      trailing: current == null
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, (persona: null)),
                    ),
                    for (final record in personas.value ?? <PersonaRecord>[])
                      Builder(
                        builder: (context) {
                          final person = people
                              .where((p) => p.id == record.personId)
                              .firstOrNull;
                          final surface = context.appColors.sectionInset;
                          final (
                            :background,
                            foreground: accent,
                            accent: _,
                          ) = person == null
                              ? personAccentColorsFor(
                                  personId: record.personId,
                                  surface: surface,
                                )
                              : personLabelColors(person, surface);
                          final label = person?.name ?? l.personaRoleSubject;
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 17,
                              backgroundColor: background,
                              foregroundColor: accent,
                              child: Text(
                                person == null
                                    ? l.chatDiaryAiIcon
                                    : personInitials(label),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            title: Text(label),
                            trailing: current?.personaId == record.personaId
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () =>
                                Navigator.pop(context, (persona: record)),
                          );
                        },
                      ),
                    if (personas.isLoading) const LinearProgressIndicator(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Text(
                        personas.hasError
                            ? l.personaError
                            : personas.value?.isEmpty != false
                            ? l.personaEmptyMenu
                            : l.personaSharedContext,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
