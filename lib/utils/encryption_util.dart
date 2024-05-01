import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class EncryptionUtil {
  static const String _algorithm =
      'aes-256-cbc'; // Advanced Encryption Standard with 256-bit key and CBC mode
  static const int _keyLength = 32; // Key length in bytes

  /// Encrypts a string using a given key.
  ///
  /// Throws [ArgumentError] if the key is not of the expected length.
  /// Throws [FormatException] if the key is not valid base64.
  /// Returns the encrypted string in base64 encoding.
  static String encrypt(String data, String key, Uint8List iv) {
    if (key.length != _keyLength) {
      throw ArgumentError('Key length must be $_keyLength bytes.');
    }

    if (iv.length != 16) {
      throw ArgumentError('IV must be 16 bytes long.');
    }

    final keyBytes = base64Decode(key);

    // Create a CBC block cipher with AES engine
    final blockCipher = CBCBlockCipher(AESEngine());

    // Initialize the cipher for encryption with key and IV (initialization vector)
    final params = ParametersWithIV(KeyParameter(keyBytes), iv);
    blockCipher.init(true, params);

    // Encrypt the data with padding
    final paddedBlockCipher =
        PaddedBlockCipherImpl(PKCS7Padding(), blockCipher);
    final encryptedBytes =
        paddedBlockCipher.process(Uint8List.fromList(utf8.encode(data)));

    return base64Encode(encryptedBytes);
  }

  /// Decrypts a string encrypted using the same key.
  ///
  /// Throws [ArgumentError] if the key is not of the expected length.
  /// Throws [FormatException] if the key or encrypted data is not valid base64.
  /// Returns the decrypted string.
  static String decrypt(
      String encryptedData, Uint8List keyBytes, String key, List<int> iv) {
    if (key.length != _keyLength) {
      throw ArgumentError('Key length must be $_keyLength bytes.');
    }

    // Validate and convert IV to Uint8List
    if (iv.length != 16) {
      throw ArgumentError('IV must be 16 bytes long.');
    }
    final ivBytes = Uint8List.fromList(iv);

    // Convert encrypted data to Uint8List
    final encryptedBytes = Uint8List.fromList(base64Decode(encryptedData));

    // Decryption logic
    final blockCipher = CBCBlockCipher(AESEngine());
    final params = ParametersWithIV(KeyParameter(keyBytes), ivBytes);
    blockCipher.init(false, params); // False for decryption mode

    final paddedBlockCipher =
        PaddedBlockCipherImpl(PKCS7Padding(), blockCipher);
    final decryptedBytes = paddedBlockCipher.process(encryptedBytes);

    // Return the decrypted string (assuming UTF-8 encoding)
    return utf8.decode(decryptedBytes);
  }

  /// Generates a random byte array of the specified length.
  static Uint8List generateRandomBytes(int length) {
    final secureRandom = SecureRandom();
    final randomBytes = Uint8List(length);
    secureRandom.nextBytes(randomBytes.length);
    return randomBytes;
  }
}
