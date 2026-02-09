import Combine
import Foundation

/// 应用数据：记录项与照片元数据，存于单文件 JSON，无 SwiftData
struct AppData: Codable {
    var subjects: [Subject]
    var photos: [Photo]
}

/// 内存 + 文件持久化：记录项与照片列表
final class DataStore: ObservableObject {
    @Published private(set) var subjects: [Subject] = []
    @Published private(set) var photos: [Photo] = []
    @Published private(set) var isLoading: Bool = true

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.kirokucamera.datastore")

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = documents.appendingPathComponent("appData.json", isDirectory: false)
        load()
    }

    // MARK: - 持久化

    private func load() {
        queue.async { [weak self] in
            guard let self = self else { return }
            // 文件 I/O 在后台线程
            let rawData = try? Data(contentsOf: self.fileURL)
            DispatchQueue.main.async {
                // JSON 解码在主线程（满足 Swift 6 MainActor 隔离要求）
                if let d = rawData, let decoded = try? JSONDecoder().decode(AppData.self, from: d) {
                    self.subjects = decoded.subjects
                    self.photos = decoded.photos
                }
                self.isLoading = false
            }
        }
    }

    private func save() {
        let subs = subjects
        let phs = photos
        let data = AppData(subjects: subs, photos: phs)
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        let url = fileURL
        queue.async {
            try? encoded.write(to: url)
        }
    }

    // MARK: - Subject

    func addSubject(_ subject: Subject) {
        subjects.append(subject)
        save()
    }

    func deleteSubject(_ subject: Subject) {
        subjects.removeAll { $0.id == subject.id }
        let ids = photos.filter { $0.subjectId == subject.id }
        for photo in ids {
            PhotoStorageService.shared.deletePhoto(fileName: photo.fileName)
        }
        photos.removeAll { $0.subjectId == subject.id }
        save()
    }

    func updateSubjectName(_ subject: Subject, name: String) {
        guard let i = subjects.firstIndex(where: { $0.id == subject.id }) else { return }
        subjects[i].name = name
        save()
    }

    /// 设置记录项封面图（nil 表示恢复为最新一张）
    func updateSubjectCover(_ subject: Subject, coverPhotoId: UUID?) {
        guard let i = subjects.firstIndex(where: { $0.id == subject.id }) else { return }
        subjects[i].coverPhotoId = coverPhotoId
        save()
    }

    // MARK: - Photo

    func addPhoto(_ photo: Photo) {
        photos.append(photo)
        save()
    }

    func deletePhoto(_ photo: Photo) {
        if let subjectId = photo.subjectId,
           let sub = subjects.first(where: { $0.id == subjectId }),
           sub.coverPhotoId == photo.id {
            updateSubjectCover(sub, coverPhotoId: nil)
        }
        PhotoStorageService.shared.deletePhoto(fileName: photo.fileName)
        photos.removeAll { $0.id == photo.id }
        save()
    }

    /// 更新照片备注
    func updatePhotoNote(_ photo: Photo, note: String?) {
        guard let i = photos.firstIndex(where: { $0.id == photo.id }) else { return }
        photos[i].note = note
        save()
    }

    // MARK: - 查询

    func photos(for subjectId: UUID) -> [Photo] {
        photos
            .filter { $0.subjectId == subjectId }
            .sorted { $0.takenAt > $1.takenAt }
    }

    func photoCount(for subjectId: UUID) -> Int {
        photos.filter { $0.subjectId == subjectId }.count
    }

    func latestPhoto(for subjectId: UUID) -> Photo? {
        photos
            .filter { $0.subjectId == subjectId }
            .max(by: { $0.takenAt < $1.takenAt })
    }

    /// 记录项封面图：优先自定义封面，否则最新一张
    func coverPhoto(for subjectId: UUID) -> Photo? {
        guard let sub = subjects.first(where: { $0.id == subjectId }) else { return nil }
        if let coverId = sub.coverPhotoId,
           let p = photos.first(where: { $0.id == coverId && $0.subjectId == subjectId }) {
            return p
        }
        return latestPhoto(for: subjectId)
    }

    func firstPhoto(for subjectId: UUID) -> Photo? {
        photos
            .filter { $0.subjectId == subjectId }
            .min(by: { $0.takenAt < $1.takenAt })
    }

    /// 记录项列表按创建时间倒序
    func sortedSubjects() -> [Subject] {
        subjects.sorted { $0.createdAt > $1.createdAt }
    }
}
