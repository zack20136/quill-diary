class SearchEntriesUseCase {
  const SearchEntriesUseCase();

  Future<List<String>> call(String query) async {
    // TODO(zack): replace placeholder results with SQLite FTS-backed search.
    return query.isEmpty ? const <String>[] : <String>['search:$query'];
  }
}
