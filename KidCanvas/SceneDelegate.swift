//
//  SceneDelegate.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/25.
//

import UIKit

/// SceneDelegate with `@objc(KDSceneDelegate)` to match the class name
/// referenced in Info.plist's `UIApplicationSceneManifest`.
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
        let mainViewController = KCMainViewController()
        mainViewController.overrideUserInterfaceStyle = .light
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = mainViewController
        window.makeKeyAndVisible()
        self.window = window
    }
}
