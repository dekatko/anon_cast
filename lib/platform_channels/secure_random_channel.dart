import 'package:flutter/services.dart';

class SecureRandomChannel {
  static const MethodChannel _channel = MethodChannel('com.example.anon_cast/secure_random');

  static Future<List<int>> generateSecureBytes(int count) async {
    final result = await _channel.invokeMethod('generateSecureBytes', count);
    return (result as List).cast<int>();
  }
}