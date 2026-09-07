//
//  ESTabBar.swift
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


/// 对原生的UITabBarItemPositioning进行扩展，通过UITabBarItemPositioning设置时，系统会自动添加insets，这使得添加背景样式的需求变得不可能实现。ESTabBarItemPositioning完全支持原有的item Position 类型，除此之外还支持完全fill模式。
///
/// - automatic: UITabBarItemPositioning.automatic
/// - fill: UITabBarItemPositioning.fill
/// - centered: UITabBarItemPositioning.centered
/// - fillExcludeSeparator: 完全fill模式，布局不覆盖tabBar顶部分割线
/// - fillIncludeSeparator: 完全fill模式，布局覆盖tabBar顶部分割线
public enum ESTabBarItemPositioning : Int {
    
    case automatic
    
    case fill
    
    case centered
    
    case fillExcludeSeparator
    
    case fillIncludeSeparator
}

/// 自定义 item 的布局宽度。
public enum ESTabBarItemLayoutWidth: Equatable {
    /// 固定宽度。所有固定项超出可用区域时会按比例缩放。
    case fixed(CGFloat)
    /// 平均分配扣除固定项之后的剩余宽度。
    case flexible
}

/// 对UITabBarDelegate进行扩展，以支持UITabBarControllerDelegate的相关方法桥接
internal protocol ESTabBarDelegate: NSObjectProtocol {

    /// 当前item是否支持选中
    ///
    /// - Parameters:
    ///   - tabBar: tabBar
    ///   - item: 当前item
    /// - Returns: Bool
    func tabBar(_ tabBar: UITabBar, shouldSelect item: UITabBarItem) -> Bool
    
    /// 当前item是否需要被劫持
    ///
    /// - Parameters:
    ///   - tabBar: tabBar
    ///   - item: 当前item
    /// - Returns: Bool
    func tabBar(_ tabBar: UITabBar, shouldHijack item: UITabBarItem) -> Bool
    
    /// 当前item的点击被劫持
    ///
    /// - Parameters:
    ///   - tabBar: tabBar
    ///   - item: 当前item
    /// - Returns: Void
    func tabBar(_ tabBar: UITabBar, didHijack item: UITabBarItem)
}



/// ESTabBar是高度自定义的UITabBar子类，通过添加UIControl的方式实现自定义tabBarItem的效果。目前支持tabBar的大部分属性的设置，例如delegate,items,selectedImge,itemPositioning,itemWidth,itemSpacing等，以后会更加细致的优化tabBar原有属性的设置效果。
open class ESTabBar: UITabBar {

    internal weak var customDelegate: ESTabBarDelegate?
    
    /// set value > 0 to change tabbar height
    /// 设置 > 0 的值了来修改TabBar的高度
    public var tabBarHeight: CGFloat?{
        didSet{
            guard tabBarHeight ?? 0 > 0 else{
                return
            }
            setNeedsLayout()
        }
    }

    /// tabBar中items布局偏移量
    public var itemEdgeInsets = UIEdgeInsets.zero
    /// 每个自定义 item 的布局宽度，数组数量必须与 items 一致。
    /// 不设置或数量不匹配时保持系统默认布局规则。
    ///
    /// Custom layout widths for item containers. The count must match `items`.
    /// When nil or invalid, the system's default layout behavior is preserved.
    open var itemLayoutWidths: [ESTabBarItemLayoutWidth]? {
        didSet {
            didReportInvalidItemLayoutWidths = false
            setNeedsLayout()
        }
    }
    /// 是否开启液态玻璃效果，默认为 true。若为 false 则禁用液态玻璃效果并使用经典 TabBar 样式。
    /// Whether liquid glass effect is enabled, default is true. If false, liquid glass effect is disabled and classic TabBar style is used.
    open var isLiquidGlassEnabled: Bool = true {
        didSet {
            if oldValue != isLiquidGlassEnabled {
                self.updateLiquidGlassEffect()
                self.setNeedsLayout()
                self.layoutIfNeeded()
            }
        }
    }
    /// 是否设置为自定义布局方式，默认为空。如果为空，则通过itemPositioning属性来设置。如果不为空则忽略itemPositioning,所以当tabBar的itemCustomPositioning属性不为空时，如果想改变布局规则，请设置此属性而非itemPositioning。
    public var itemCustomPositioning: ESTabBarItemPositioning? {
        didSet {
            if let itemCustomPositioning = itemCustomPositioning {
                switch itemCustomPositioning {
                case .fill:
                    itemPositioning = .fill
                case .automatic:
                    itemPositioning = .automatic
                case .centered:
                    itemPositioning = .centered
                default:
                    break
                }
            }
            self.reload()
        }
    }
    /// tabBar自定义item的容器view
    internal var containers = [ESTabBarItemContainer]()
    /// 避免 layoutSubviews 重复输出相同的配置错误。
    private var didReportInvalidItemLayoutWidths = false
    /// 缓存当前选中的 index
    internal var selectedIndex: Int = 0
    /// 缓存当前选中的 item
    internal var customSelectedItem: UITabBarItem?
    /// 缓存当前tabBarController用来判断是否存在"More"Tab
    internal weak var tabBarController: UITabBarController?
    /// 自定义'More'按钮样式，继承自ESTabBarItemContentView
    open var moreContentView: ESTabBarItemContentView? = ESTabBarItemMoreContentView.init() {
        didSet { self.reload() }
    }
    
    open override var items: [UITabBarItem]? {
        didSet {
            didReportInvalidItemLayoutWidths = false
            self.reload()
        }
    }
    
    open var isEditing: Bool = false {
        didSet {
            if oldValue != isEditing {
                self.updateLayout()
            }
        }
    }
    
    open override func setItems(_ items: [UITabBarItem]?, animated: Bool) {
        super.setItems(items, animated: animated)
        self.reload()
    }
    
    open override func beginCustomizingItems(_ items: [UITabBarItem]) {
        ESTabBarController.printError("beginCustomizingItems(_:) is unsupported in ESTabBar.")
        super.beginCustomizingItems(items)
    }
    
    open override func endCustomizing(animated: Bool) -> Bool {
        ESTabBarController.printError("endCustomizing(_:) is unsupported in ESTabBar.")
        return super.endCustomizing(animated: animated)
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        self.updateLayout()
    }
    
    open override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        if !isLiquidGlassEnabled {
            updateLiquidGlassEffect()
        }
    }

    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !isLiquidGlassEnabled {
            guard self.isUserInteractionEnabled, !self.isHidden, self.alpha > 0.01 else {
                return nil
            }
            // Route touches only to containers when liquid glass is disabled
            for container in containers {
                let converted = self.convert(point, to: container)
                if container.point(inside: converted, with: event) {
                    if let hit = container.hitTest(converted, with: event) {
                        return hit
                    }
                }
            }
            // Check non-system custom subviews
            for subview in subviews.reversed() {
                if subview is ESTabBarItemContainer { continue }
                let className = NSStringFromClass(type(of: subview))
                if className.contains("Platter") || className.contains("Liquid") || className.contains("Lens") || className.contains("Button") || className.contains("Selection") {
                    continue
                }
                let converted = self.convert(point, to: subview)
                if subview.point(inside: converted, with: event) {
                    if let hit = subview.hitTest(converted, with: event) {
                        return hit
                    }
                }
            }
            if self.point(inside: point, with: event) {
                return self
            }
            return nil
        }
        return super.hitTest(point, with: event)
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        let defaultSize = super.sizeThatFits(size)
        if let tabBarHeight, tabBarHeight > 0{
            return CGSize(width: defaultSize.width, height: tabBarHeight)
        }
        return defaultSize
    }
    
    open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        var b = super.point(inside: point, with: event)
        if !b {
            for container in containers {
                if container.point(inside: CGPoint.init(x: point.x - container.frame.origin.x, y: point.y - container.frame.origin.y), with: event) {
                    b = true
                }
            }
        }
        return b
    }
    
}

internal extension ESTabBar /* Layout */ {
    
    private func isSystemTabBarButton(_ view: UIView) -> Bool {
        let className = NSStringFromClass(type(of: view))
        return className.contains("TabBarButton") || className.contains("TabButton")
    }

    private func findSystemButtonGroups() -> [[UIView]] {
        var parentViews = [UIView]()
        func findParents(in view: UIView) {
            var hasSystemButtonChild = false
            for subview in view.subviews {
                if isSystemTabBarButton(subview) {
                    hasSystemButtonChild = true
                } else if !(subview is ESTabBarItemContainer) {
                    findParents(in: subview)
                }
            }
            if hasSystemButtonChild {
                parentViews.append(view)
            }
        }
        findParents(in: self)
        
        var groups = [[UIView]]()
        for parent in parentViews {
            let buttons = parent.subviews.filter { isSystemTabBarButton($0) }
                .sorted { $0.frame.origin.x < $1.frame.origin.x }
            if !buttons.isEmpty {
                groups.append(buttons)
            }
        }
        return groups
    }
    
    private func findReferenceSystemButtons(from groups: [[UIView]]) -> [UIView] {
        for group in groups {
            if let first = group.first, let parent = first.superview {
                let parentName = NSStringFromClass(type(of: parent))
                if !parentName.contains("Selected") {
                    return group
                }
            }
        }
        return groups.first ?? []
    }
    
    private func updateLiquidGlassEffect() {
        func processView(_ view: UIView) {
            let className = NSStringFromClass(type(of: view))
            if className.contains("Platter") || className.contains("Liquid") || className.contains("Lens") || className.contains("TabSelection") || className.contains("ClearGlass") || className.contains("DestOut") {
                view.isHidden = !isLiquidGlassEnabled
                view.alpha = isLiquidGlassEnabled ? 1.0 : 0.0
                view.isUserInteractionEnabled = isLiquidGlassEnabled
                if !isLiquidGlassEnabled {
                    view.layer.opacity = 0.0
                    view.layer.isHidden = true
                    view.gestureRecognizers?.forEach { $0.isEnabled = false }
                } else {
                    view.layer.opacity = 1.0
                    view.layer.isHidden = false
                    view.gestureRecognizers?.forEach { $0.isEnabled = true }
                }
            }
            for subview in view.subviews {
                if !(subview is ESTabBarItemContainer) {
                    processView(subview)
                }
            }
        }
        processView(self)
    }

    func updateLayout() {
        guard let tabBarItems = self.items else {
            ESTabBarController.printError("empty items")
            return
        }
        
        updateLiquidGlassEffect()
        
        let buttonGroups = findSystemButtonGroups()
        
        if isCustomizing {
            for group in buttonGroups {
                for (idx, btn) in group.enumerated() {
                    if idx < tabBarItems.count {
                        btn.isHidden = false
                    }
                }
            }
            moreContentView?.isHidden = true
            for (_, container) in containers.enumerated(){
                container.isHidden = true
            }
        } else {
            for group in buttonGroups {
                for (idx, btn) in group.enumerated() {
                    if idx < tabBarItems.count {
                        let item = tabBarItems[idx]
                        let shouldHide = (item is ESTabBarItem) || (isMoreItem(idx) && moreContentView != nil)
                        btn.isHidden = shouldHide
                    }
                }
            }
            for (_, container) in containers.enumerated(){
                container.isHidden = false
            }
        }
        
        var layoutBaseSystem = true
        if let itemCustomPositioning = itemCustomPositioning {
            switch itemCustomPositioning {
            case .fill, .automatic, .centered:
                break
            case .fillIncludeSeparator, .fillExcludeSeparator:
                layoutBaseSystem = false
            }
        }
        
        if layoutBaseSystem {
            // 不要逐个拷贝系统 UITabBarButton.frame：iOS 26/27 选中项会变宽。
            // 在系统 item 的整体区域内按配置宽度布局；未配置时保持等宽。
            let refButtons = findReferenceSystemButtons(from: buttonGroups)
            // 指定自定义宽度时使用 TabBar 的完整可用区域，不能沿用系统按钮区域，
            // 否则系统预留的左右边距会压缩普通 item，无法铺满剩余空间。
            if let widths = validItemLayoutWidths {
                layoutContainers(in: fullContentLayoutRect(), widths: widths)
            } else if isLiquidGlassEnabled {
                if #available(iOS 26.0, *) {
                    // iOS 26 的系统选中项宽度会变化，只能使用整体区域等分。
                    layoutContainersEqually(in: contentLayoutRect(referenceButtons: refButtons))
                } else {
                    // 旧系统保持原有行为，包括系统的 itemWidth、itemSpacing 和 centered 布局。
                    layoutContainersUsingSystemFrames(
                        refButtons,
                        fallback: fullContentLayoutRect()
                    )
                }
            } else {
                // 保持关闭 Liquid Glass 时的旧行为：所有 item 铺满完整可用宽度。
                layoutContainersEqually(in: fullContentLayoutRect())
            }
        } else {
            // Custom itemPositioning
            var x: CGFloat = itemEdgeInsets.left
            var y: CGFloat = itemEdgeInsets.top
            switch itemCustomPositioning! {
            case .fillExcludeSeparator:
                if y <= 0.0 {
                    y += 1.0
                }
            default:
                break
            }
            let width = bounds.size.width - itemEdgeInsets.left - itemEdgeInsets.right
            let availableHeight = bounds.size.height - y - itemEdgeInsets.bottom
            let height: CGFloat
            if let tabBarHeight = tabBarHeight, tabBarHeight > 0 {
                height = tabBarHeight - y - itemEdgeInsets.bottom
            } else if safeAreaInsets.bottom > 0 {
                height = max(0, availableHeight - safeAreaInsets.bottom)
            } else {
                height = availableHeight
            }
            let eachWidth = itemWidth == 0.0 ? (containers.isEmpty ? 0.0 : width / CGFloat(containers.count)) : itemWidth
            let eachSpacing = itemSpacing == 0.0 ? 0.0 : itemSpacing
            
            if let widths = validItemLayoutWidths {
                let rect = CGRect(x: itemEdgeInsets.left, y: y, width: width, height: height)
                layoutContainers(in: rect, widths: widths)
            } else {
                for container in containers {
                    container.frame = CGRect.init(x: x, y: y, width: eachWidth, height: height)
                    x += eachWidth
                    x += eachSpacing
                }
            }
        }
    }

    /// TabBar 去除显式边距后的完整布局区域。
    private func fullContentLayoutRect() -> CGRect {
        let x = itemEdgeInsets.left
        let width = max(0, bounds.width - itemEdgeInsets.left - itemEdgeInsets.right)
        return CGRect(x: x, y: itemEdgeInsets.top, width: width, height: itemSlotHeight())
    }

    private var validItemLayoutWidths: [ESTabBarItemLayoutWidth]? {
        guard let itemLayoutWidths else { return nil }
        guard itemLayoutWidths.count == containers.count else {
            if !didReportInvalidItemLayoutWidths {
                ESTabBarController.printError("itemLayoutWidths count must match items count")
                didReportInvalidItemLayoutWidths = true
            }
            return nil
        }
        didReportInvalidItemLayoutWidths = false
        return itemLayoutWidths
    }

    private func layoutContainersEqually(in rect: CGRect) {
        guard !containers.isEmpty, rect.width > 0, rect.height > 0 else { return }
        let width = rect.width / CGFloat(containers.count)
        var x = rect.minX
        for container in containers {
            container.frame = CGRect(x: x, y: rect.minY, width: width, height: rect.height)
            x += width
        }
    }

    private func layoutContainersUsingSystemFrames(_ buttons: [UIView], fallback rect: CGRect) {
        guard !containers.isEmpty else { return }
        let fallbackWidth = rect.width / CGFloat(containers.count)
        for (index, container) in containers.enumerated() {
            if index < buttons.count {
                let button = buttons[index]
                let frame = button.superview == self
                    ? button.frame
                    : button.convert(button.bounds, to: self)
                if !frame.isEmpty {
                    container.frame = frame
                    continue
                }
            }
            container.frame = CGRect(
                x: rect.minX + CGFloat(index) * fallbackWidth,
                y: rect.minY,
                width: fallbackWidth,
                height: rect.height
            )
        }
    }

    /// 按固定宽度与弹性宽度布局。
    private func layoutContainers(in rect: CGRect, widths: [ESTabBarItemLayoutWidth]) {
        guard !containers.isEmpty, rect.width > 0, rect.height > 0 else { return }

        let fixedWidth = widths.reduce(CGFloat.zero) { result, width in
            guard case let .fixed(value) = width else { return result }
            return result + max(0, value)
        }
        let flexibleCount = widths.reduce(0) { result, width in
            if case .flexible = width { return result + 1 }
            return result
        }

        // 固定项已经占满可用区域时，保留所有 item 的可点击区域并退回等宽。
        if flexibleCount > 0, fixedWidth >= rect.width {
            layoutContainersEqually(in: rect)
            return
        }

        // 全部固定项均为无效宽度时退回等宽。
        if flexibleCount == 0, fixedWidth == 0 {
            layoutContainersEqually(in: rect)
            return
        }

        let flexibleWidth = flexibleCount > 0
            ? (rect.width - fixedWidth) / CGFloat(flexibleCount)
            : 0
        let scale = flexibleCount == 0 && fixedWidth > rect.width
            ? rect.width / fixedWidth
            : 1
        let renderedFixedWidth = fixedWidth * scale
        // 全部为固定宽度且总宽不足时，将整组 item 水平居中。
        var x = flexibleCount == 0
            ? rect.minX + max(0, rect.width - renderedFixedWidth) / 2
            : rect.minX

        for (index, container) in containers.enumerated() {
            let width: CGFloat
            switch widths[index] {
            case let .fixed(value):
                width = max(0, value) * scale
            case .flexible:
                width = flexibleWidth
            }
            container.frame = CGRect(x: x, y: rect.minY, width: width, height: rect.height)
            x += width
        }
    }

    /// 自定义容器的水平布局区域：优先系统 button 的并集 / Liquid Glass platter，避免跟选中态不等宽的单个 button。
    private func contentLayoutRect(referenceButtons: [UIView]) -> CGRect {
        let height = itemSlotHeight()
        let y = itemEdgeInsets.top

        var union: CGRect?
        for btn in referenceButtons {
            let frame = btn.superview == self ? btn.frame : btn.convert(btn.bounds, to: self)
            guard frame.width > 1, frame.height > 1 else { continue }
            union = union.map { $0.union(frame) } ?? frame
        }
        if let union, union.width > 1 {
            return CGRect(x: union.minX, y: y, width: union.width, height: height)
        }

        if let platter = tabBarPlatterFrame(), platter.width > 1 {
            return CGRect(x: platter.minX, y: y, width: platter.width, height: height)
        }

        var left = itemEdgeInsets.left
        var right = itemEdgeInsets.right
        if #available(iOS 26.0, *) {
            left = max(left, layoutMargins.left)
            right = max(right, layoutMargins.right)
        }
        let width = max(0, bounds.size.width - left - right)
        return CGRect(x: left, y: y, width: width, height: height)
    }

    private func itemSlotHeight() -> CGFloat {
        let availableHeight = bounds.size.height - itemEdgeInsets.top - itemEdgeInsets.bottom
        let standardHeight: CGFloat
        if let tabBarHeight = tabBarHeight, tabBarHeight > 0 {
            standardHeight = tabBarHeight - itemEdgeInsets.top - itemEdgeInsets.bottom
        } else if safeAreaInsets.bottom > 0 {
            standardHeight = max(0, availableHeight - safeAreaInsets.bottom)
        } else {
            standardHeight = availableHeight
        }
        return standardHeight > 0 ? standardHeight : availableHeight
    }

    private func tabBarPlatterFrame() -> CGRect? {
        func findPlatter(in view: UIView) -> UIView? {
            let className = NSStringFromClass(type(of: view))
            if className.contains("Platter") {
                return view
            }
            for subview in view.subviews where !(subview is ESTabBarItemContainer) {
                if let found = findPlatter(in: subview) {
                    return found
                }
            }
            return nil
        }
        guard let platter = findPlatter(in: self) else { return nil }
        let frame = platter.convert(platter.bounds, to: self)
        return frame.width > 1 ? frame : nil
    }
}

internal extension ESTabBar /* Actions */ {
    
    func isMoreItem(_ index: Int) -> Bool {
        return ESTabBarController.isShowingMore(tabBarController) && (index == (items?.count ?? 0) - 1)
    }
    
    func removeAll() {
        for container in containers {
            container.removeFromSuperview()
        }
        containers.removeAll()
    }
    
    func reload() {
        removeAll()
        guard let tabBarItems = self.items else {
            ESTabBarController.printError("empty items")
            return
        }
        for (idx, item) in tabBarItems.enumerated() {
            let container = ESTabBarItemContainer.init(self, tag: 1000 + idx)
            self.addSubview(container)
            self.containers.append(container)
            
            if let item = item as? ESTabBarItem {
                container.addSubview(item.contentView)
                let isSelected = (customSelectedItem != nil) ? (item == customSelectedItem) : (idx == selectedIndex)
                if isSelected {
                    item.contentView.select(animated: false, completion: nil)
                } else {
                    item.contentView.deselect(animated: false, completion: nil)
                }
            }
            if self.isMoreItem(idx), let moreContentView = moreContentView {
                container.addSubview(moreContentView)
            }
        }
        
        if customSelectedItem == nil, !tabBarItems.isEmpty {
            let initialIdx = min(max(0, selectedIndex), tabBarItems.count - 1)
            customSelectedItem = tabBarItems[initialIdx]
        }
        
        self.updateAccessibilityLabels()
        self.setNeedsLayout()
    }
    
    @objc func highlightAction(_ sender: AnyObject?) {
        guard let container = sender as? ESTabBarItemContainer else {
            return
        }
        let newIndex = max(0, container.tag - 1000)
        guard newIndex < items?.count ?? 0, let item = self.items?[newIndex], item.isEnabled == true else {
            return
        }
        
        if (customDelegate?.tabBar(self, shouldSelect: item) ?? true) == false {
            return
        }
        
        if let item = item as? ESTabBarItem {
            item.contentView.highlight(animated: true, completion: nil)
        } else if self.isMoreItem(newIndex) {
            moreContentView?.highlight(animated: true, completion: nil)
        }
    }
    
    @objc func dehighlightAction(_ sender: AnyObject?) {
        guard let container = sender as? ESTabBarItemContainer else {
            return
        }
        let newIndex = max(0, container.tag - 1000)
        guard newIndex < items?.count ?? 0, let item = self.items?[newIndex], item.isEnabled == true else {
            return
        }
        
        if (customDelegate?.tabBar(self, shouldSelect: item) ?? true) == false {
            return
        }
        
        if let item = item as? ESTabBarItem {
            item.contentView.dehighlight(animated: true, completion: nil)
        } else if self.isMoreItem(newIndex) {
            moreContentView?.dehighlight(animated: true, completion: nil)
        }
    }
    
    @objc func selectAction(_ sender: AnyObject?) {
        guard let container = sender as? ESTabBarItemContainer else {
            return
        }
        select(itemAtIndex: container.tag - 1000, animated: true)
    }
    
    @objc func select(itemAtIndex idx: Int, animated: Bool) {
        let newIndex = max(0, idx)
        let currentIndex = (customSelectedItem != nil) ? (items?.firstIndex(of: customSelectedItem!) ?? selectedIndex) : selectedIndex
        guard newIndex < items?.count ?? 0, let item = self.items?[newIndex], item.isEnabled == true else {
            return
        }
        
        if (customDelegate?.tabBar(self, shouldSelect: item) ?? true) == false {
            return
        }
        
        if (customDelegate?.tabBar(self, shouldHijack: item) ?? false) == true {
            customDelegate?.tabBar(self, didHijack: item)
            if animated {
                if let item = item as? ESTabBarItem {
                    item.contentView.select(animated: animated, completion: {
                        item.contentView.deselect(animated: false, completion: nil)
                    })
                } else if self.isMoreItem(newIndex) {
                    moreContentView?.select(animated: animated, completion: {
                        self.moreContentView?.deselect(animated: animated, completion: nil)
                    })
                }
            }
            return
        }
        
        if currentIndex != newIndex {
            if let items = self.items {
                for (i, itm) in items.enumerated() {
                    if i != newIndex {
                        if let customItem = itm as? ESTabBarItem {
                            customItem.contentView.deselect(animated: animated, completion: nil)
                        } else if self.isMoreItem(i) {
                            moreContentView?.deselect(animated: animated, completion: nil)
                        }
                    }
                }
            }
            if let item = item as? ESTabBarItem {
                item.contentView.select(animated: animated, completion: nil)
            } else if self.isMoreItem(newIndex) {
                moreContentView?.select(animated: animated, completion: nil)
            }
        } else if currentIndex == newIndex {
            if let item = item as? ESTabBarItem {
                item.contentView.reselect(animated: animated, completion: nil)
            } else if self.isMoreItem(newIndex) {
                moreContentView?.reselect(animated: animated, completion: nil)
            }
            
            if let tabBarController = tabBarController {
                var navVC: UINavigationController?
                if let n = tabBarController.selectedViewController as? UINavigationController {
                    navVC = n
                } else if let n = tabBarController.selectedViewController?.navigationController {
                    navVC = n
                }
                
                if let navVC = navVC {
                    if navVC.viewControllers.contains(tabBarController) {
                        if navVC.viewControllers.count > 1 && navVC.viewControllers.last != tabBarController {
                            navVC.popToViewController(tabBarController, animated: true);
                        }
                    } else {
                        if navVC.viewControllers.count > 1 {
                            navVC.popToRootViewController(animated: animated)
                        }
                    }
                }
            
            }
        }
        
        self.selectedIndex = newIndex
        self.customSelectedItem = item
        delegate?.tabBar?(self, didSelect: item)
        self.updateAccessibilityLabels()
    }
    
    func updateAccessibilityLabels() {
        guard let tabBarItems = self.items, tabBarItems.count == self.containers.count else {
            return
        }
        
        for (idx, item) in tabBarItems.enumerated() {
            let container = self.containers[idx]
            container.accessibilityIdentifier = item.accessibilityIdentifier
            container.accessibilityTraits = item.accessibilityTraits
            
            let isCurrentSelected = (item == customSelectedItem) || (item == selectedItem) || (idx == selectedIndex)
            if isCurrentSelected {
                container.accessibilityTraits = container.accessibilityTraits.union(.selected)
            }
            
            if let explicitLabel = item.accessibilityLabel {
                container.accessibilityLabel = explicitLabel
                container.accessibilityHint = item.accessibilityHint ?? container.accessibilityHint
            } else {
                var accessibilityTitle = ""
                if let item = item as? ESTabBarItem {
                    accessibilityTitle = item.accessibilityLabel ?? item.title ?? ""
                }
                if self.isMoreItem(idx) {
                    accessibilityTitle = NSLocalizedString("More_TabBarItem", bundle: Bundle(for:ESTabBarController.self), comment: "")
                }
                
                let formatString = NSLocalizedString(isCurrentSelected ? "TabBarItem_Selected_AccessibilityLabel" : "TabBarItem_AccessibilityLabel",
                                                     bundle: Bundle(for: ESTabBarController.self),
                                                     comment: "")
                container.accessibilityLabel = String(format: formatString, accessibilityTitle, idx + 1, tabBarItems.count)
            }
            
        }
    }
}
