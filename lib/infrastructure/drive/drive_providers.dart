import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'drive_backup_service.dart';

final driveBackupServiceProvider = Provider<DriveBackupService>((Ref ref) {
  return GoogleDriveBackupService();
});
