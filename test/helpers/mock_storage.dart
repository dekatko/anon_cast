import 'package:anon_cast/services/key_manager.dart';

/// In-memory implementation of [KeyManagerStorage] for tests.
/// Use in integration tests to avoid platform-specific secure storage.
class InMemoryKeyManagerStorage implements KeyManagerStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  /// Clear all entries (for test teardown).
  void clear() => _store.clear();
}
