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

    final blockCipher = CBCBlockCipher(AESEngine());
    final params = ParametersWithIV(KeyParameter(keyBytes), iv);
    final paddedBlockCipher =
        PaddedBlockCipherImpl(PKCS7Padding(), blockCipher);
    final plainBytes = data.isEmpty
        ? Uint8List.fromList([_emptySentinel])
        : Uint8List.fromList(utf8.encode(data));
    paddedBlockCipher.init(true, PaddedBlockCipherParameters(params, null));
    final encryptedBytes = paddedBlockCipher.process(plainBytes);
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

    final blockCipher = CBCBlockCipher(AESEngine());
    final params = ParametersWithIV(KeyParameter(keyBytes), ivBytes);
    final paddedBlockCipher =
        PaddedBlockCipherImpl(PKCS7Padding(), blockCipher);
    paddedBlockCipher.init(false, PaddedBlockCipherParameters(params, null));
    final decryptedBytes = paddedBlockCipher.process(encryptedBytes);
    if (decryptedBytes.length == 1 &&
        decryptedBytes[0] == _emptySentinel) {
      return '';
    }
    return utf8.decode(decryptedBytes);
  }

  /// Encrypts [data] with raw [keyBytes] (32 bytes) and [iv] (16 bytes).
  /// Returns base64-encoded ciphertext. Use for key rotation when key is Uint8List.
  /// Empty string is encoded as a single sentinel byte so round-trip works (pointycastle does not support 0-length input).
  static String encryptWithKeyBytes(
      String data, Uint8List keyBytes, Uint8List iv) {
    if (keyBytes.length != _keyLength) {
      throw ArgumentError(
          'Key must be $_keyLength bytes, got ${keyBytes.length}.');
    }
    if (iv.length != 16) {
      throw ArgumentError('IV must be 16 bytes long.');
    }
    final plainBytes = data.isEmpty
        ? Uint8List.fromList([_emptySentinel])
        : Uint8List.fromList(utf8.encode(data));
    final blockCipher = CBCBlockCipher(AESEngine());
    final params = ParametersWithIV(KeyParameter(keyBytes), iv);
    final paddedBlockCipher =
        PaddedBlockCipherImpl(PKCS7Padding(), blockCipher);
    paddedBlockCipher.init(true, PaddedBlockCipherParameters(params, null));
    final encryptedBytes = paddedBlockCipher.process(plainBytes);
    return base64Encode(encryptedBytes);
  }

  static const int _emptySentinel = 0;

  /// Decrypts [encryptedData] (base64) with raw [keyBytes] and [iv].
  static String decryptWithKeyBytes(
      String encryptedData, Uint8List keyBytes, Uint8List iv) {
    if (keyBytes.length != _keyLength) {
      throw ArgumentError(
          'Key must be $_keyLength bytes, got ${keyBytes.length}.');
    }
    if (iv.length != 16) {
      throw ArgumentError('IV must be 16 bytes long.');
    }
    final encryptedBytes = Uint8List.fromList(base64Decode(encryptedData));
    final blockCipher = CBCBlockCipher(AESEngine());
    final params = ParametersWithIV(KeyParameter(keyBytes), iv);
    final paddedBlockCipher =
        PaddedBlockCipherImpl(PKCS7Padding(), blockCipher);
    paddedBlockCipher.init(false, PaddedBlockCipherParameters(params, null));
    final decryptedBytes = paddedBlockCipher.process(encryptedBytes);
    if (decryptedBytes.length == 1 &&
        decryptedBytes[0] == _emptySentinel) {
      return '';
    }
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
