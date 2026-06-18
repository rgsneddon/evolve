/// No OAuth session persistence on web / unsupported platforms.
class GrokSessionPersistence {
  const GrokSessionPersistence();

  Future<Map<String, dynamic>?> load() async => null;

  Future<void> save(Map<String, dynamic> data) async {}

  Future<void> clear() async {}
}