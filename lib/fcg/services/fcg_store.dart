import '../models/fcg_models.dart';

abstract class FcgStore {
  Future<FcgWardDatabase?> load();
  Future<void> save(FcgWardDatabase database);
}