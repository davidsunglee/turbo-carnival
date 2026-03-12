import UIKit
import Engine2043

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let viewController = UIViewController()
        let metalView = MetalView(frame: window.bounds)
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewController.view.addSubview(metalView)
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        self.window = window
    }
}
