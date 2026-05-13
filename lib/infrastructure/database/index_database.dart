class IndexDatabase {
  const IndexDatabase();

  Future<void> initialize() async {
    // TODO(zack): create schema, migrations, and rebuild fallback hooks.
  }

  Future<void> rebuild() async {
    // TODO(zack): scan encrypted entries and regenerate query tables.
  }
}
