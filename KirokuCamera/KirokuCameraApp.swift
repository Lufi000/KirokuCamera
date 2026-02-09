import SwiftUI
import UIKit

// 隐藏系统返回键时仍启用左边缘侧滑返回（对 UIKit 导航有效）
private final class PopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let view = gestureRecognizer.view else { return false }
        var r: UIResponder? = view
        while let n = r?.next {
            if let nc = n as? UINavigationController { return nc.viewControllers.count > 1 }
            r = n
        }
        return false
    }
}

private let popGestureDelegate = PopGestureDelegate()

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = popGestureDelegate
    }
}

@main
struct KirokuCameraApp: App {
    @StateObject private var dataStore = DataStore()

    init() {
        // 窗口背景色：消除启动时 UIWindow 默认黑色
        let kirokuBg = UIColor(red: 250/255, green: 237/255, blue: 216/255, alpha: 1)
        UIWindow.appearance().backgroundColor = kirokuBg

        let titleColor = UIColor(red: 74/255, green: 74/255, blue: 74/255, alpha: 1.0)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        UINavigationBar.appearance().standardAppearance = appearance
        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithDefaultBackground()
        scrollEdge.largeTitleTextAttributes = [.foregroundColor: titleColor]
        scrollEdge.titleTextAttributes = [.foregroundColor: titleColor]
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdge
        UINavigationBar.appearance().compactAppearance = appearance
        let primaryPurple = UIColor(red: 146/255, green: 91/255, blue: 193/255, alpha: 1.0)
        UINavigationBar.appearance().tintColor = primaryPurple
        UIBarButtonItem.appearance().tintColor = primaryPurple
    }

    var body: some Scene {
        WindowGroup {
            StoryboardRootView()
                .environmentObject(dataStore)
                .preferredColorScheme(.light)
                .background(Color(red: 250/255, green: 237/255, blue: 216/255))
        }
    }
}
