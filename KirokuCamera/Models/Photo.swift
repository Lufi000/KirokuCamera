import Foundation
import UIKit

/// 照片元数据：纯数据，存 JSON；图片文件仍存 Documents/Photos/
struct Photo: Identifiable, Codable, Equatable {
    var id: UUID
    var fileName: String
    var takenAt: Date
    var note: String?
    var subjectId: UUID?

    init(fileName: String, subjectId: UUID?, takenAt: Date = Date(), note: String? = nil, id: UUID = UUID()) {
        self.id = id
        self.fileName = fileName
        self.takenAt = takenAt
        self.note = note
        self.subjectId = subjectId
    }

    /// 获取图片的完整路径
    var filePath: URL {
        PhotoStorageService.shared.photoDirectory.appendingPathComponent(fileName)
    }

    /// 加载图片
    func loadImage() -> UIImage? {
        guard let data = try? Data(contentsOf: filePath) else { return nil }
        return UIImage(data: data)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/M/d"
        return f.string(from: takenAt)
    }

    var detailedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: takenAt)
    }
}
