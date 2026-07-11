import Flutter
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

    window = UIWindow(windowScene: windowScene)
    let vc = FlutterViewController(engine: appDelegate.flutterEngine, nibName: nil, bundle: nil)
    window?.rootViewController = vc
    window?.makeKeyAndVisible()

    // Só regista os plugins depois de o FlutterViewController estar ligado ao motor.
    GeneratedPluginRegistrant.register(with: appDelegate.flutterEngine)
  }
}
