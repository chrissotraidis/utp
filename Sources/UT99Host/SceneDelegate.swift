import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GameViewController()
        self.window = window
        window.makeKeyAndVisible()
        requestLandscape(for: windowScene)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        requestLandscape(for: windowScene)
    }

    private func requestLandscape(for windowScene: UIWindowScene) {
        if #available(iOS 16.0, *) {
            guard !windowScene.interfaceOrientation.isLandscape else { return }
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            windowScene.requestGeometryUpdate(
                UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
            ) { error in
                NSLog("UT99 requested landscape scene geometry: %@", error.localizedDescription)
            }
        }
    }
}
