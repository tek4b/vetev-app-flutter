import Flutter
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  let engine = FlutterEngine(name: "vetev_engine")

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)

    guard let windowScene = scene as? UIWindowScene else { return }
    window = UIWindow(windowScene: windowScene)
    let vc = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    window?.rootViewController = vc
    window?.makeKeyAndVisible()
  }
}
