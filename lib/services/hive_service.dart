import 'package:hive_flutter/adapters.dart';

class HiveService {
  static Future<void> init() async {
    await Hive.initFlutter();
    // ... register adapters
  }

  static Future<void> saveEntity<T>(String boxName, T entity) async {
    final box = await Hive.openBox(boxName);
    box.put(entity.toString(), entity); // Use a descriptive key
  }

// ... other methods (getChatSession, etc.)
}
