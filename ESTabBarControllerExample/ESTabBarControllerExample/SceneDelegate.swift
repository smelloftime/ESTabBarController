//
//  SceneDelegate.swift
//  ESTabBarControllerExample
//
//  Created by huaiyonghu on 2026/8/17.
//  Copyright © 2026 Vincent Li. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            window = UIWindow(windowScene: windowScene)
            window?.backgroundColor = .clear
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateInitialViewController()
            window!.rootViewController = vc
            window?.makeKeyAndVisible()
        }
    }
}
