import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:cryptography/dart.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/recovery/recovery_key_identity.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/portable/backup_archive_inspection.dart';
import 'package:quill_diary/infrastructure/storage/shared/archive_extract.dart';
import 'package:quill_diary/shared/data_versions.dart';

const backupIntegrityPath = 'backup_integrity.json.enc';
const backupIntegrityMaxBytes = 16 * 1024 * 1024;

const backupRootFiles = {
  'recovery.json',
  'manifest.json.enc',
  'people.json.enc',
  'tag_styles.json.enc',
  'pinned_entries.json',
  'ai_settings.json.enc',
};

String? backupMemberType(String path) {
  if (path == 'entries') return 'directory';
  if (backupRootFiles.contains(path)) return 'file';
  final parts = p.posix.split(path);
  if (parts.length == 4 &&
      (parts.first == 'entries' &&
              (path.endsWith('.md.enc') || path.endsWith('.chat.json.enc')) ||
          parts.first == 'assets' && path.endsWith('.enc'))) {
    return 'file';
  }
  if (parts.length == 3 &&
      parts.first == 'personas' &&
      isPrefixedId(parts[1], 'per') &&
      parts.last == 'state.json.enc') {
    return 'file';
  }
  if (parts.length == 2 &&
      parts.first == 'preservation' &&
      parts.last.startsWith('tag_styles_') &&
      path.endsWith('.json.enc')) {
    return 'file';
  }
  return null;
}

String? readBackupId(Archive archive, Map<String, Object?> recovery) {
  final markerExists =
      recovery.containsKey('backup_format_version') ||
      recovery.containsKey('backup_id');
  final hasIntegrity = archive.files.any(
    (entry) => safeArchiveRelativePath(entry.name) == backupIntegrityPath,
  );
  if (!markerExists && !hasIntegrity) return null;
  final id = recovery['backup_id'];
  if (recovery['backup_format_version'] != DataVersions.vaultBackup ||
      id is! String ||
      !isPrefixedId(id, 'bkp') ||
      !hasIntegrity) {
    throw const VaultBackupException(VaultBackupIssue.invalidBackupIntegrity);
  }
  return id;
}

Map<String, Object?> backupMember({
  required String path,
  required int length,
  required List<int> hash,
}) => {
  'path': path,
  'type': backupMemberType(path),
  'length': length,
  'sha256': hash.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
};

Future<Map<String, Object?>> _measureMember(ArchiveFile entry) async {
  final path = safeArchiveRelativePath(entry.name);
  final type = backupMemberType(path);
  if (type != (entry.isFile ? 'file' : 'directory')) {
    throw const VaultBackupException(VaultBackupIssue.invalidBackupIntegrity);
  }
  final sink = const DartSha256().newHashSink();
  final output = SinkOutputStream(sink);
  if (entry.isFile) writeZipEntry(entry, output);
  output.closeSync();
  return backupMember(
    path: path,
    length: entry.size,
    hash: (await sink.hash()).bytes,
  );
}

Future<Map<String, Object?>> backupIntegrityPayload({
  required String backupId,
  required RecoveryMetadata metadata,
  required VaultBackupPurpose purpose,
  required List<Map<String, Object?>> members,
}) async => {
  'version': DataVersions.vaultBackup,
  'backup_id': backupId,
  'recovery_identity': (await RecoveryKeyIdentity.fromMetadata(metadata))
      .toJson(),
  'purpose': purpose.name,
  'members': members,
};

Future<VaultBackupPurpose> verifyBackupIntegrity({
  required Archive archive,
  required LocalCryptoService crypto,
  required String backupId,
  required RecoveryMetadata metadata,
  required List<int> wrapKey,
}) async {
  final envelope = readZipEntry(
    archive,
    relativePath: backupIntegrityPath,
    maxBytes: backupIntegrityMaxBytes,
  );
  if (envelope == null ||
      safeArchiveRelativePath(archive.files.last.name) != backupIntegrityPath) {
    throw const VaultBackupException(VaultBackupIssue.invalidBackupIntegrity);
  }
  final document = crypto.parseFileBytes(envelope);
  if (document.header.fileId != 'backup_integrity_$backupId' ||
      document.header.vaultId != metadata.vaultId ||
      document.header.contentType != 'application/json') {
    throw const VaultBackupException(VaultBackupIssue.invalidBackupIntegrity);
  }
  final decoded = jsonDecode(
    utf8.decode(
      await crypto.decryptBytes(
        headerBytes: document.headerBytes,
        ciphertextBytes: document.ciphertextBytes,
        context: DecryptionContext.recovery(
          recoveryWrapKey: wrapKey,
          vaultId: metadata.vaultId,
        ),
      ),
    ),
  ) as Map<String, Object?>;
  final purpose = VaultBackupPurpose.values
      .where((purpose) => purpose.name == decoded['purpose'])
      .firstOrNull;
  if (purpose == null) {
    throw const VaultBackupException(VaultBackupIssue.invalidBackupIntegrity);
  }
  final members = [
    for (final member in archive.files)
      if (safeArchiveRelativePath(member.name) != backupIntegrityPath)
        await _measureMember(member),
  ];
  final expected = await backupIntegrityPayload(
    backupId: backupId,
    metadata: metadata,
    purpose: purpose,
    members: members,
  );
  if (jsonEncode(decoded) != jsonEncode(expected)) {
    throw const VaultBackupException(VaultBackupIssue.invalidBackupIntegrity);
  }
  return purpose;
}
