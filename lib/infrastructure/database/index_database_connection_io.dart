import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../storage/vault_path_strategy.dart';

Future<QueryExecutor> openIndexConnection(VaultPathStrategy pathStrategy) async {
  return driftDatabase(
    name: 'journal_index',
    native: DriftNativeOptions(
      databasePath: pathStrategy.indexDatabasePath,
    ),
  );
}
