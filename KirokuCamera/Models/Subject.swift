import Foundation

/// 记录项（Subject）：用于区分不同的拍摄对象（纯数据，存 JSON）
struct Subject: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    /// 自定义封面照片 id；nil 表示使用最新一张
    var coverPhotoId: UUID?

    init(name: String, id: UUID = UUID(), createdAt: Date = Date(), coverPhotoId: UUID? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.coverPhotoId = coverPhotoId
    }

    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, coverPhotoId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        coverPhotoId = try c.decodeIfPresent(UUID.self, forKey: .coverPhotoId)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(coverPhotoId, forKey: .coverPhotoId)
    }
}
