import SwiftUI
import UIKit

/// 从 Main.storyboard 加载首屏（导航 + 相册列表），并注入 DataStore；用于以 Storyboard 为主入口的 UI。
struct StoryboardRootView: View {
    @EnvironmentObject private var dataStore: DataStore

    var body: some View {
        StoryboardRootRepresentable(dataStore: dataStore)
            .ignoresSafeArea()
    }
}

private struct StoryboardRootRepresentable: UIViewControllerRepresentable {
    let dataStore: DataStore

    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let host = storyboard.instantiateInitialViewController() as? HomeHostViewController else {
            return UIViewController()
        }
        host.dataStore = dataStore
        return host
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
