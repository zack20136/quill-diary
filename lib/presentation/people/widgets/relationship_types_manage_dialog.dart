import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/domain/people/person.dart';
import 'package:quill_diary/domain/people/relationship_type.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/storage/storage_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/people_labels.dart';
import 'package:quill_diary/shared/presentation/widgets/accent_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_action_button.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/utils/user_facing_error.dart';

/// 人物頁頂列與管理 dialog 共用的關係圖示。
const IconData kPeopleRelationshipsIcon = Icons.diversity_3_rounded;

/// 管理關係類型：依目前語系單欄新增／改名／刪除，立刻寫入 catalog。
Future<void> showRelationshipTypesManageDialog(BuildContext context) async {
  final Color barrierColor = context.appColors.scrim;
  await showDialog<void>(
    context: context,
    barrierColor: barrierColor,
    builder: (BuildContext ctx) {
      final bool compact = MediaQuery.sizeOf(ctx).width < 600;
      return SafeArea(
        child: Dialog(
          key: const Key('relationship-types-manage-dialog'),
          insetPadding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 24,
            vertical: compact ? 12 : 24,
          ),
          backgroundColor: Colors.transparent,
          child: const _RelationshipTypesManageDialog(),
        ),
      );
    },
  );
}

class _RelationshipTypesManageDialog extends ConsumerStatefulWidget {
  const _RelationshipTypesManageDialog();

  @override
  ConsumerState<_RelationshipTypesManageDialog> createState() =>
      _RelationshipTypesManageDialogState();
}

class _RelationshipTypesManageDialogState
    extends ConsumerState<_RelationshipTypesManageDialog> {
  final TextEditingController _addCtrl = TextEditingController();
  String? _renamingId;
  final TextEditingController _renameCtrl = TextEditingController();
  bool _busy = false;
  List<RelationshipType>? _localTypes;

  @override
  void initState() {
    super.initState();
    _addCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _renameCtrl.dispose();
    super.dispose();
  }

  bool get _preferZh => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('zh');

  String get _languageCode => Localizations.localeOf(context).languageCode;

  InputDecoration _fieldDecoration({
    required String labelText,
    String? hintText,
    Widget? suffixIcon,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: cs.surface.withValues(alpha: 0.95),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<UnlockedVaultSession?> _unlockedSession() async {
    final AppSessionState state = await ref.read(
      effectiveAppSessionProvider.future,
    );
    if (!state.isUnlocked || state.session == null) {
      return null;
    }
    return state.session;
  }

  void _toastLabelError(ArgumentError error, AppLocalizations l10n) {
    final String message = error.message?.toString() ?? '';
    showAppFeedbackToast(
      context,
      message.contains('已存在') || message.contains('already')
          ? l10n.peopleRelationshipNameDuplicate
          : l10n.peopleRelationshipNameEmpty,
    );
  }

  Future<void> _runMutation(
    Future<void> Function(UnlockedVaultSession session) action, {
    void Function(Object error)? onError,
    bool clearLocalOnSuccess = true,
  }) async {
    final UnlockedVaultSession? session = await _unlockedSession();
    if (session == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action(session);
      if (!mounted) {
        return;
      }
      ref.invalidate(peopleCatalogProvider);
      if (clearLocalOnSuccess) {
        setState(() => _localTypes = null);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (onError != null) {
        onError(error);
      } else {
        showAppFeedbackToast(
          context,
          userFacingErrorMessage(error, l10n: context.l10n),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addType() async {
    final String label = _addCtrl.text.trim();
    final AppLocalizations l10n = context.l10n;
    if (label.isEmpty) {
      showAppFeedbackToast(context, l10n.peopleRelationshipNameEmpty);
      return;
    }
    await _runMutation(
      (UnlockedVaultSession session) async {
        await ref
            .read(vaultPeopleServiceProvider)
            .addRelationshipType(session, label: label, preferZh: _preferZh);
        _addCtrl.clear();
      },
      onError: (Object error) {
        if (error is ArgumentError) {
          _toastLabelError(error, l10n);
        } else {
          showAppFeedbackToast(
            context,
            userFacingErrorMessage(error, l10n: l10n),
          );
        }
      },
    );
  }

  Future<void> _commitRename(String id) async {
    final String label = _renameCtrl.text.trim();
    final AppLocalizations l10n = context.l10n;
    if (label.isEmpty) {
      showAppFeedbackToast(context, l10n.peopleRelationshipNameEmpty);
      return;
    }
    await _runMutation(
      (UnlockedVaultSession session) async {
        await ref
            .read(vaultPeopleServiceProvider)
            .renameRelationshipType(
              session,
              id: id,
              label: label,
              preferZh: _preferZh,
            );
        _renamingId = null;
        _renameCtrl.clear();
      },
      onError: (Object error) {
        if (error is ArgumentError) {
          _toastLabelError(error, l10n);
        } else {
          showAppFeedbackToast(
            context,
            userFacingErrorMessage(error, l10n: l10n),
          );
        }
      },
    );
  }

  Future<void> _deleteType(RelationshipType type) async {
    final AppLocalizations l10n = context.l10n;
    final PeopleCatalog? catalog = ref
        .read(peopleCatalogProvider)
        .asData
        ?.value;
    final int usage = catalog == null
        ? 0
        : catalog.people
              .where((Person person) => person.relationships.contains(type.id))
              .length;

    if (usage > 0) {
      final bool confirmed = await showAppConfirmDialog(
        context: context,
        title: l10n.peopleDeleteRelationshipConfirmTitle,
        content: Text(l10n.peopleDeleteRelationshipConfirmBody(usage)),
        cancelLabel: l10n.commonActionCancel,
        confirmLabel: l10n.commonActionDelete,
        confirmStyle: AppConfirmStyle.destructive,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }

    await _runMutation((UnlockedVaultSession session) async {
      await ref
          .read(vaultPeopleServiceProvider)
          .deleteRelationshipType(session, type.id);
      if (_renamingId == type.id) {
        _renamingId = null;
        _renameCtrl.clear();
      }
    });
  }

  void _beginRename(RelationshipType type) {
    setState(() {
      _renamingId = type.id;
      _renameCtrl.text = relationshipTypeLabel(type, _languageCode);
    });
  }

  void _cancelRename() {
    setState(() {
      _renamingId = null;
      _renameCtrl.clear();
    });
  }

  bool _sameTypeIds(List<RelationshipType> a, List<RelationshipType> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) {
        return false;
      }
    }
    return true;
  }

  Future<void> _reorderTypes(
    List<RelationshipType> types,
    int oldIndex,
    int newIndex,
  ) async {
    if (_busy || _renamingId != null || types.length < 2) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) {
      return;
    }
    final List<RelationshipType> next = List<RelationshipType>.from(types);
    final RelationshipType moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    setState(() => _localTypes = next);
    final List<String> orderedIds = <String>[
      for (final RelationshipType type in next) type.id,
    ];

    await _runMutation(
      (UnlockedVaultSession session) async {
        await ref
            .read(vaultPeopleServiceProvider)
            .reorderRelationshipTypes(session, orderedIds);
      },
      clearLocalOnSuccess: false,
      onError: (Object error) {
        setState(() => _localTypes = null);
        showAppFeedbackToast(
          context,
          userFacingErrorMessage(error, l10n: context.l10n),
        );
      },
    );
  }

  Widget _typeRow({
    required AppLocalizations l10n,
    required ColorScheme cs,
    required ThemeData theme,
    required RelationshipType type,
    required int index,
    required bool canReorder,
  }) {
    final bool renaming = _renamingId == type.id;
    if (renaming) {
      return Padding(
        key: ValueKey<String>('rel-type-${type.id}'),
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _renameCtrl,
                enabled: !_busy,
                autofocus: true,
                decoration: _fieldDecoration(
                  labelText: l10n.peopleRenameRelationshipAction,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => unawaited(_commitRename(type.id)),
              ),
            ),
            IconButton(
              tooltip: l10n.commonActionConfirm,
              onPressed: _busy
                  ? null
                  : () => unawaited(_commitRename(type.id)),
              icon: Icon(Icons.check_rounded, color: cs.primary),
            ),
            IconButton(
              tooltip: l10n.commonActionCancel,
              onPressed: _busy ? null : _cancelRename,
              icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final String label = relationshipTypeLabel(type, _languageCode);
    final Widget handle = canReorder
        ? ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: l10n.peopleReorderRelationshipTooltip,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.drag_handle_rounded,
              color: cs.outlineVariant,
            ),
          );

    return Material(
      key: ValueKey<String>('rel-type-${type.id}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : () => _beginRename(type),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: Row(
            children: <Widget>[
              handle,
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.peopleRenameRelationshipAction,
                onPressed: _busy ? null : () => _beginRename(type),
                color: cs.primary,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              IconButton(
                tooltip: l10n.peopleDeleteRelationshipAction,
                onPressed: _busy
                    ? null
                    : () => unawaited(_deleteType(type)),
                color: cs.error,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<PeopleCatalog> catalogAsync = ref.watch(
      peopleCatalogProvider,
    );
    final List<RelationshipType> catalogTypes =
        catalogAsync.asData?.value.relationshipTypes ??
        defaultBuiltinRelationshipTypes();
    final List<RelationshipType> types = _localTypes ?? catalogTypes;
    if (_localTypes != null &&
        catalogAsync.hasValue &&
        _sameTypeIds(_localTypes!, catalogTypes)) {
      // catalog 已跟上本地排序後，改以 provider 為準
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _localTypes != null) {
          setState(() => _localTypes = null);
        }
      });
    }
    final bool canReorder =
        !_busy && _renamingId == null && types.length > 1;

    return AccentDialogShell(
      icon: kPeopleRelationshipsIcon,
      title: l10n.peopleManageRelationshipsTitle,
      onClose: _busy ? null : () => Navigator.of(context).pop(),
      closeEnabled: !_busy,
      footer: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Align(
          alignment: Alignment.centerRight,
          child: AppActionButton(
            label: l10n.commonActionClose,
            icon: Icons.check_rounded,
            appearance: AppActionButtonAppearance.primary,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.peopleManageRelationshipsGuide,
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.4,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _addCtrl,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            decoration: _fieldDecoration(
              labelText: l10n.peopleAddRelationshipAction,
              hintText: l10n.peopleAddRelationshipHint,
              suffixIcon: IconButton(
                tooltip: l10n.peopleAddRelationshipAction,
                onPressed: _busy || _addCtrl.text.trim().isEmpty
                    ? null
                    : () => unawaited(_addType()),
                icon: Icon(Icons.add_rounded, color: cs.primary),
              ),
            ),
            onSubmitted: (_) => unawaited(_addType()),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.42,
            ),
            child: Material(
              color: cs.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: types.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 28,
                      ),
                      child: Text(
                        l10n.peopleManageRelationshipsEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.outline,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: types.length,
                      onReorderStart: (_) {
                        unawaited(HapticFeedback.selectionClick());
                      },
                      onReorderItem: (int oldIndex, int newIndex) {
                        unawaited(_reorderTypes(types, oldIndex, newIndex));
                      },
                      proxyDecorator:
                          (Widget child, int index, Animation<double> animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (BuildContext context, Widget? child) {
                            final double t = Curves.easeInOut.transform(
                              animation.value,
                            );
                            return Material(
                              elevation: 2 + 4 * t,
                              borderRadius: BorderRadius.circular(14),
                              color: cs.surface,
                              shadowColor: theme.shadowColor.withValues(
                                alpha: 0.18,
                              ),
                              child: child,
                            );
                          },
                          child: child,
                        );
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return _typeRow(
                          l10n: l10n,
                          cs: cs,
                          theme: theme,
                          type: types[index],
                          index: index,
                          canReorder: canReorder,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
