import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// Test data for encryption flow tests.
class EncryptionTestData {
  EncryptionTestData._();

  /// Short plain text.
  static const String shortText = 'Hello, admin';

  /// Long message (stress test).
  static String get longText =>
      'Lorem ipsum dolor sit amet. ' * 200; // ~7k chars

  /// Special characters and Unicode.
  static const String specialChars = 'émojis: 🎉 中文 ñ ü ß © ®';

  /// Empty string (edge case).
  static const String emptyText = '';

  /// Newlines and tabs.
  static const String whitespaceText = 'Line1\nLine2\tTab\r\n';

  /// All test cases for parameterized tests.
  static List<MapEntry<String, String>> get allCases => [
        const MapEntry('short', shortText),
        MapEntry('long', longText),
        const MapEntry('special', specialChars),
        const MapEntry('empty', emptyText),
        const MapEntry('whitespace', whitespaceText),
      ];
}

/// Assertion helpers for encryption validation.
class EncryptionAssertions {
  /// Asserts [ciphertext] is valid base64 and not equal to [plaintext].
  static void expectValidCiphertext(String plaintext, String ciphertext) {
    expect(ciphertext, isNotEmpty);
    expect(ciphertext, isNot(equals(plaintext)));
    expect(
      () => base64Decode(ciphertext),
      returnsNormally,
      reason: 'Ciphertext should be valid base64',
    );
  }

  /// Asserts [decrypted] equals [expectedPlaintext] (message integrity).
  static void expectDecryptedEquals(String expectedPlaintext, String decrypted) {
    expect(decrypted, equals(expectedPlaintext));
  }

  /// Asserts [content] looks like base64 (alphanumeric + / + =).
  static void expectBase64(String content) {
    expect(content, isNotEmpty);
    final allowed = RegExp(r'^[A-Za-z0-9+/]+=*$');
    expect(allowed.hasMatch(content), isTrue, reason: 'Should be base64');
  }

  /// Asserts two ciphertexts are different (different IV or key).
  static void expectCiphertextsDifferent(String a, String b) {
    expect(a, isNot(equals(b)));
  }

  /// Asserts [iv] is 16 bytes (for AES block size).
  static void expectValidIv(List<int>? iv) {
    expect(iv, isNotNull);
    expect(iv!.length, equals(16));
  }
}
