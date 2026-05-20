import 'package:flutter/material.dart';

import '../../../infrastructure/storage/restore_precheck.dart';

/// 還原備份前收集建立該備份時保存的復原金鑰。
Future<String?> showRestoreRecoveryKeyDialog(
  BuildContext context, {
  required RestorePrecheck precheck,
  String? validationError,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => _RestoreRecoveryKeyDialog(
      precheck: precheck,
      validationError: validationError,
    ),
  );
}

class _RestoreRecoveryKeyDialog extends StatefulWidget {
  const _RestoreRecoveryKeyDialog({
    required this.precheck,
    this.validationError,
  });

  final RestorePrecheck precheck;
  final String? validationError;

  @override
  State<_RestoreRecoveryKeyDialog> createState() => _RestoreRecoveryKeyDialogState();
}

class _RestoreRecoveryKeyDialogState extends State<_RestoreRecoveryKeyDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _errorText = widget.validationError;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _subtitle() {
    final RestorePrecheck precheck = widget.precheck;
    if (precheck.recoveryKeyRotatedSinceBackup) {
      return '此備份在「更新復原金鑰」之前建立。請輸入建立該備份時保存的舊金鑰（不是目前這把新金鑰）。';
    }
    if (precheck.sameVaultId) {
      return '本機無法自動解鎖此備份。請輸入建立此備份時保存的復原金鑰。';
    }
    return '此備份來自其他裝置或不同授權狀態。請輸入建立此備份時保存的復原金鑰。';
  }

  void _submit() {
    final String key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _errorText = '請輸入復原金鑰。');
      return;
    }
    Navigator.of(context).pop(key);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? hint = widget.precheck.backupRecoveryHint;

    return AlertDialog(
      title: const Text('輸入備份復原金鑰'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _subtitle(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '金鑰正確後才會開始還原；錯誤則不會覆寫本機資料。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hint != null && hint.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '金鑰提示：$hint',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: '復原金鑰',
                hintText: 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX',
                errorText: _errorText,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('驗證並還原'),
        ),
      ],
    );
  }
}
