import UIKit
import Flutter
import Security

@UIApplicationMain
@objc class RunnerAppDelegate: UIResponder, UIApplicationDelegate, FlutterPluginRegistry {
  private var flutterEngine: FlutterEngine!

  override func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    flutterEngine = FlutterEngine(nil)
    flutterEngine.run(withEntrypoint: #function)
    return true
  }

  func flutter(_ flutterEngine: FlutterEngine,
              needsChannel name: String,
              binaryMessenger: FlutterBinaryMessenger) -> FlutterPlugin? {
    if name == "com.example.anon_cast/secure_random" {
      return SecureRandomChannel()
    }
    return nil
  }
}

class SecureRandomChannel: NSObject, FlutterPlugin {
  private let secureRandom = SecRandomCreate(nil)!

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "generateSecureBytes" {
      guard let count = call.arguments as? Int else {
        result(FlutterError(code: "invalid_arguments", message: "Missing count argument", details: nil))
        return
      }

      var randomBytes = [UInt8](repeating: 0, count: count)
      let status = SecRandomGenerateBytes(secureRandom, count, &randomBytes)
      if status == errSecSuccess {
        result(randomBytes.map { Int($0) })
      } else {
        result(FlutterError(code: "secure_random_error", message: "Failed to generate random bytes", details: nil))
      }
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}