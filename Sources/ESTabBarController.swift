//
//  ESTabBarController.swift
//
//  Created by Vincent Li on 2017/2/8.
//  Copyright (c) 2013-2020 ESTabBarController (https://github.com/eggswift/ESTabBarController)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit

/// 是否需要自定义点击事件回调类型
public typealias ESTabBarControllerShouldHijackHandler = ((_ tabBarController: UITabBarController, _ viewController: UIViewController, _ index: Int) -> (Bool))
/// 自定义点击事件回调类型
public typealias ESTabBarControllerDidHijackHandler = ((_ tabBarController: UITabBarController, _ viewController: UIViewController, _ index: Int) -> (Void))

open class ESTabBarController: UITabBarController, ESTabBarDelegate {
    
    /// 打印异常
    public static func printError(_ description: String) {
        #if DEBUG
            print("ERROR: ESTabBarController catch an error '\(description)' \n")
        #endif
    }
    
    /// 当前tabBarController是否存在"More"tab
    public static func isShowingMore(_ tabBarController: UITabBarController?) -> Bool {
        return tabBarController?.moreNavigationController.parent != nil
    }

    /// Ignore next selection or not.
    fileprivate var ignoreNextSelection = false
    /// 上一次真正被选中的 tab。hijack 项不应成为 selectedIndex。
    /// Last tab that was actually selected. A hijacked item must not become selectedIndex.
    fileprivate var lastNonHijackedIndex: Int = 0
    /// 同一次点击里，自定义容器和系统 UITabBar 都可能回调，记录已劫持的具体 item，
    /// 避免重复触发，同时不影响同一 RunLoop 内其他 hijack item。
    /// Custom containers and the system UITabBar may both fire for one tap.
    fileprivate weak var hijackedItemInCurrentEvent: UITabBarItem?

    /// Should hijack select action or not.
    open var shouldHijackHandler: ESTabBarControllerShouldHijackHandler?
    /// Hijack select action.
    open var didHijackHandler: ESTabBarControllerDidHijackHandler?
    
    /// 是否开启液态玻璃效果，默认为 true。
    /// Whether liquid glass effect is enabled, default is true.
    open var isLiquidGlassEnabled: Bool = true {
        didSet {
            (tabBar as? ESTabBar)?.isLiquidGlassEnabled = isLiquidGlassEnabled
        }
    }
    
    /// Observer tabBarController's selectedViewController. change its selection when it will-set.
    /// iOS 26/27 上系统仍可能把 selectedViewController 指到 hijack 项，这里直接拒绝。
    open override var selectedViewController: UIViewController? {
        get { super.selectedViewController }
        set {
            guard let newValue = newValue else {
                super.selectedViewController = nil
                return
            }
            if isHijackViewController(newValue) {
                ignoreNextSelection = false
                return
            }
            if ignoreNextSelection {
                ignoreNextSelection = false
            } else if let tabBar = self.tabBar as? ESTabBar, let items = tabBar.items,
                      let index = viewControllers?.firstIndex(of: newValue) {
                let value = (ESTabBarController.isShowingMore(self) && index > items.count - 1) ? items.count - 1 : index
                tabBar.select(itemAtIndex: value, animated: false)
            }
            super.selectedViewController = newValue
            if let index = viewControllers?.firstIndex(of: newValue) {
                lastNonHijackedIndex = index
            }
        }
    }
    
    /// Observer tabBarController's selectedIndex. change its selection when it will-set.
    /// iOS 26/27 上系统仍可能把 selectedIndex 设到 hijack 项，这里直接拒绝，避免内容页切到占位 VC。
    open override var selectedIndex: Int {
        get { super.selectedIndex }
        set {
            if isHijackIndex(newValue) {
                ignoreNextSelection = false
                return
            }
            if ignoreNextSelection {
                ignoreNextSelection = false
            } else if let tabBar = self.tabBar as? ESTabBar, let items = tabBar.items {
                let value = (ESTabBarController.isShowingMore(self) && newValue > items.count - 1) ? items.count - 1 : newValue
                tabBar.select(itemAtIndex: value, animated: false)
            }
            super.selectedIndex = newValue
            lastNonHijackedIndex = newValue
        }
    }
    
    /// Customize set tabBar use KVC.
    open override func viewDidLoad() {
        super.viewDidLoad()
        let tabBar = { () -> ESTabBar in 
            let tabBar = ESTabBar()
            tabBar.delegate = self
            tabBar.customDelegate = self
            tabBar.tabBarController = self
            tabBar.isLiquidGlassEnabled = self.isLiquidGlassEnabled
            return tabBar
        }()
        self.setValue(tabBar, forKey: "tabBar")
    }

    // MARK: - UITabBar delegate
    open override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let idx = tabBar.items?.firstIndex(of: item) else {
            return;
        }
        if let items = tabBar.items, idx == items.count - 1, ESTabBarController.isShowingMore(self) {
            ignoreNextSelection = true
            selectedViewController = moreNavigationController
            return;
        }
        if let viewControllers = viewControllers, idx < viewControllers.count {
            let vc = viewControllers[idx]
            // iOS 26/27：系统 UITabBar 在自定义容器劫持之后仍会回调 didSelect。
            // hijack 语义是「不选中该 tab」，因此不能改 selectedIndex。
            if shouldHijackHandler?(self, vc, idx) == true {
                if hijackedItemInCurrentEvent !== item {
                    self.tabBar(tabBar, didHijack: item)
                }
                restoreSelectionIfHijacked()
                return
            }
            ignoreNextSelection = true
            selectedIndex = idx
            delegate?.tabBarController?(self, didSelect: vc)
        }
    }
    
    open override func tabBar(_ tabBar: UITabBar, willBeginCustomizing items: [UITabBarItem]) {
        if let tabBar = tabBar as? ESTabBar {
            tabBar.updateLayout()
        }
    }
    
    open override func tabBar(_ tabBar: UITabBar, didEndCustomizing items: [UITabBarItem], changed: Bool) {
        if let tabBar = tabBar as? ESTabBar {
            tabBar.updateLayout()
        }
    }
    
    // MARK: - ESTabBar delegate
    internal func tabBar(_ tabBar: UITabBar, shouldSelect item: UITabBarItem) -> Bool {
        if let idx = tabBar.items?.firstIndex(of: item), let viewControllers = viewControllers, idx < viewControllers.count {
            let vc = viewControllers[idx]
            return delegate?.tabBarController?(self, shouldSelect: vc) ?? true
        }
        return true
    }
    
    internal func tabBar(_ tabBar: UITabBar, shouldHijack item: UITabBarItem) -> Bool {
        if let idx = tabBar.items?.firstIndex(of: item), let viewControllers = viewControllers, idx < viewControllers.count {
            let vc = viewControllers[idx]
            return shouldHijackHandler?(self, vc, idx) ?? false
        }
        return false
    }
    
    internal func tabBar(_ tabBar: UITabBar, didHijack item: UITabBarItem) {
        guard hijackedItemInCurrentEvent !== item else { return }
        hijackedItemInCurrentEvent = item
        if let idx = tabBar.items?.firstIndex(of: item), let viewControllers = viewControllers, idx < viewControllers.count {
            let vc = viewControllers[idx]
            didHijackHandler?(self, vc, idx)
        }
        // 系统可能在 didSelect 返回之后才真正切走 selectedIndex，下一拍再兜底切回。
        DispatchQueue.main.async { [weak self] in
            if self?.hijackedItemInCurrentEvent === item {
                self?.hijackedItemInCurrentEvent = nil
            }
            self?.restoreSelectionIfHijacked()
        }
    }
    
    private func isHijackIndex(_ index: Int) -> Bool {
        guard let viewControllers, index >= 0, index < viewControllers.count else { return false }
        return shouldHijackHandler?(self, viewControllers[index], index) ?? false
    }
    
    private func isHijackViewController(_ viewController: UIViewController) -> Bool {
        guard let index = viewControllers?.firstIndex(of: viewController) else { return false }
        return isHijackIndex(index)
    }
    
    /// 若内容页已被切到 hijack 占位 VC，则切回上一个真实 tab。
    private func restoreSelectionIfHijacked() {
        guard isHijackIndex(selectedIndex) else { return }
        let restore = lastNonHijackedIndex
        guard restore != selectedIndex, !isHijackIndex(restore) else { return }
        ignoreNextSelection = true
        selectedIndex = restore
    }
    
}
