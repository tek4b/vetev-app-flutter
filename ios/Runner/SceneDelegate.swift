import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let vc = FlutterViewController()
    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = vc
    window?.makeKeyAndVisible()
  }
}
