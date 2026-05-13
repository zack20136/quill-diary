import '../../infrastructure/database/index_database.dart';

class SearchEntriesUseCase {
  const SearchEntriesUseCase(this._indexDatabase);

  final IndexDatabase _indexDatabase;

  Future<List<EntryIndexRecord>> call(String query) {
    return _indexDatabase.searchEntries(query);
  }
}
