import SwiftUI
import UIKit

/// Storyboard 相册列表页：UIKit 实现，点击进入 SwiftUI 记录项详情
final class SubjectListViewController: UITableViewController {

    /// 由 StoryboardRootView 注入；未注入时列表为空，避免闪退
    var dataStore: DataStore?

    private var subjects: [Subject] {
        dataStore?.sortedSubjects() ?? []
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = UIColor(red: 250/255, green: 237/255, blue: 216/255, alpha: 1)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SubjectCell")
        navigationController?.navigationBar.tintColor = UIColor(red: 146/255, green: 91/255, blue: 193/255, alpha: 1)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "camera"),
            style: .plain,
            target: self,
            action: #selector(openCamera)
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    @objc private func openCamera() {
        guard let dataStore = dataStore else { return }
        let cameraView = QuickCameraView().environmentObject(dataStore)
        let hosting = UIHostingController(rootView: cameraView)
        hosting.modalPresentationStyle = .fullScreen
        present(hosting, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = subjects.count
        if count == 0 { return 1 }
        return count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SubjectCell", for: indexPath)
        if subjects.isEmpty {
            cell.textLabel?.text = "暂无记录项，点击右上角相机拍摄"
            cell.textLabel?.textColor = UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1)
            cell.selectionStyle = .none
        } else {
            let subject = subjects[indexPath.row]
            cell.textLabel?.text = subject.name
            cell.textLabel?.textColor = UIColor(red: 74/255, green: 74/255, blue: 74/255, alpha: 1)
            cell.selectionStyle = .default
        }
        cell.backgroundColor = UIColor(white: 1, alpha: 0.5)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let dataStore = dataStore, !subjects.isEmpty else { return }
        let subject = subjects[indexPath.row]
        let detailView = SubjectDetailView(subject: subject)
            .environmentObject(dataStore)
        let hosting = UIHostingController(rootView: detailView)
        navigationController?.pushViewController(hosting, animated: true)
    }
}
