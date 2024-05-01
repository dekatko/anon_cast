import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

class EncryptionKeyService {
  final _storage = const FlutterSecureStorage();
  SecureRandom _random = SecureRandom(); // For generating random ephemeral keys

  Future<AsymmetricKeyPair<PublicKey, PrivateKey>>
      generateEphemeralKeyPair() async {
    //
    var keyParams = ECKeyGeneratorParameters(ECCurve_secp256r1());
    var generator = ECKeyGenerator();
    generator.init(ParametersWithRandom(keyParams, _random));

    return generator.generateKeyPair();
  }

  // Store private key securely using flutter_secure_storage
  Future<void> storePrivateKey(PrivateKey privateKey) async {
    // Encode the private key to a String format (PEM or DER)
    // final privateKeyPem =
    //     await PEMEncoder().encode(PrivateKeyParameter(privateKey));
    //
    // PemCodec(PemLabel.privateKey).encode(privateKey.toString());
    //
    // // Store the encoded private key in secure storage
    // await _storage.write(key: 'privateKey', value: privateKeyPem);
  }

  // Retrieve private key securely using flutter_secure_storage
  Future<PrivateKey?> retrievePrivateKey() async {
    // final privateKeyPem = await _storage.read(key: 'privateKey');
    //
    // if (privateKeyPem == null) {
    //   return null; // No private key found
    // }
    //
    // // Decode the PEM encoded private key
    // final privateKeyParameter =
    //     await PEMDecoder().decodePrivateKey(privateKeyPem);
    //
    // PemCodec(PemLabel.privateKey).decode(privateKeyPem);
    //
    // // Return the decoded private key
    // return privateKeyParameter.privateKey;
  }

// PrivateKey getPrivateKeyBytes(PrivateKey privateKey) {
// Extract the underlying ASN.1 encoded key data
// final pkcs8 = privateKey.toASN1DER();

// You can optionally base64 encode the ASN.1 data for debugging or storage (not required for PEM encoding)
// final base64Pkcs8 = base64Encode(pkcs8);

// return pkcs8;
// }

// Additional methods for key storage/retrieval (optional based on your needs)
// ...
}
