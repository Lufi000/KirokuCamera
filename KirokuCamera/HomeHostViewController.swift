import SwiftUI
import UIKit

/// Storyboard 首屏容器：仅嵌入原有 SwiftUI HomeView，保持相册列表样式与交互一致
final class HomeHostViewController: UIViewController {

    /// 由 StoryboardRootView 注入
    var dataStore: DataStore?

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let dataStore = dataStore else { return }
        let homeView = HomeView().environmentObject(dataStore)
        let hosting = UIHostingController(rootView: homeView)
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
