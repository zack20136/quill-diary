abstract class DriveBackupService {
  Future<void> uploadBackup(String backupPath);

  Future<List<String>> listBackups();
}
