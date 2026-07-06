//
//  SceneDelegate.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/25.
//

import UIKit
import KCCommon

/// 使用 `@objc(KDSceneDelegate)` 暴露类名，与 Info.plist 中
/// `UIApplicationSceneManifest` 引用的类名保持一致。
@objc(KDSceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let compositionRoot = KCAppCompositionRoot()
        let mainViewController = compositionRoot.makeMainViewController()
        mainViewController.overrideUserInterfaceStyle = .light
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = mainViewController
        window.makeKeyAndVisible()
        self.window = window
        self.requestLandscapeGeometry(for: windowScene)
    }

    private func requestLandscapeGeometry(for windowScene: UIWindowScene) {
        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
        windowScene.requestGeometryUpdate(preferences) { error in
            KCLog.warning("横屏几何请求失败: \(error.localizedDescription)")
        }
    }
}
