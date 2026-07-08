import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'index_database_manager.dart';
import '../storage/storage_path_providers.dart';

final indexDatabaseManagerProvider = Provider<IndexDatabaseManager>((Ref ref) {
  return IndexDatabaseManager(ref.watch(vaultPathStrategyProvider));
});
