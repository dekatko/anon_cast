import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

/// Scheduler for key rotation background checks. Uses Workmanager to run a
/// periodic task; the task sets a flag file so the main isolate can run
/// the actual rotation (Hive + secure storage require main isolate).
class RotationScheduler {
  static const String taskName = 'keyRotationCheck';
  static const String flagFileName = 'rotation_check_requested.flag';

  /// Top-level dispatcher for Workmanager. Run from main: Workmanager().initialize(RotationScheduler.callbackDispatcher);
  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      if (task == taskName) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$flagFileName');
          await file.writeAsString(DateTime.now().toIso8601String());
        } catch (_) {}
      }
      return true;
    });
  }

  /// Registers the periodic task (e.g. every 24 hours). Call from main.dart.
  /// No-op on web (Workmanager is not supported).
  static Future<void> registerPeriodicTask() async {
    if (kIsWeb) return;
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(hours: 24),
    );
  }

  /// Returns true if a rotation check was requested by the background task.
  static Future<bool> isCheckRequested() async {
    if (kIsWeb) return false;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$flagFileName');
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Clears the rotation-check-requested flag (call after running rotation).
  static Future<void> clearCheckRequested() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$flagFileName');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
