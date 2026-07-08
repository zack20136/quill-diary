import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vault_path_strategy.dart';

final vaultPathStrategyProvider = Provider<VaultPathStrategy>((Ref ref) {
  return const VaultPathStrategy();
});
