import SwiftUI
import UIKit

/// 在隐藏系统返回键时仍启用左边缘侧滑返回（需在需要侧滑的页面加 .background(SwipeBackEnabler())）
struct SwipeBackEnabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            uiView.findNavigationController()?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

private extension UIView {
    func findNavigationController() -> UINavigationController? {
        var r: UIResponder? = self
        while let n = r?.next {
            if let nc = n as? UINavigationController { return nc }
            r = n
        }
        if let window = self.window, let root = window.rootViewController {
            return findNavigationController(from: root)
        }
        return nil
    }

    private func findNavigationController(from vc: UIViewController) -> UINavigationController? {
        if let nc = vc as? UINavigationController, nc.viewControllers.count > 1 { return nc }
        if let presented = vc.presentedViewController,
           let nc = findNavigationController(from: presented) { return nc }
        for child in vc.children {
            if let nc = findNavigationController(from: child) { return nc }
        }
        return nil
    }
}
