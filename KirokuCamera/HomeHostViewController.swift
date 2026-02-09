import SwiftUI
import UIKit

/// Storyboard 首屏容器：仅嵌入原有 SwiftUI HomeView，保持相册列表样式与交互一致
final class HomeHostViewController: UIViewController {

    /// 由 StoryboardRootView 注入
    var dataStore: DataStore?

    override func viewDidLoad() {
        super.viewDidLoad()
        // 立即设置背景色，避免数据加载期间黑屏
        view.backgroundColor = UIColor(red: 250/255, green: 237/255, blue: 216/255, alpha: 1)
        guard let dataStore = dataStore else { return }
        let homeView = HomeView().environmentObject(dataStore)
        let hosting = UIHostingController(rootView: homeView)
        hosting.view.backgroundColor = UIColor(red: 250/255, green: 237/255, blue: 216/255, alpha: 1)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
    }
}
