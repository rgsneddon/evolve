import '../models/fcg_models.dart';
import 'fcg_store.dart';

/// In-memory store for tests.
class FcgStoreMemory implements FcgStore {
  FcgWardDatabase? _data;

  @override
  Future<FcgWardDatabase?> load() async => _data;

  @override
  Future<void> save(FcgWardDatabase database) async {
    _data = database;
  }
}