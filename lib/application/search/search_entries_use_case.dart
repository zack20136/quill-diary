import '../../infrastructure/database/index_database.dart';
import '../../infrastructure/storage/vault_repository.dart';

class SearchEntriesUseCase {
  const SearchEntriesUseCase(this._repository);

  final VaultRepository _repository;

  Future<List<EntryIndexRecord>> call(String query) {
    return _repository.searchEntries(query);
  }
}
