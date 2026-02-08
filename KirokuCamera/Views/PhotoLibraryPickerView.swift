import SwiftUI
import Photos

/// 自定义照片库：选图后不关闭，在同一界面出现「保存」按钮
struct PhotoLibraryPickerView: View {
    @Environment(\.dismiss) private var dismiss

    /// 用户选图并点保存后回调 (image, 拍摄日期可选)
    var onPick: (UIImage, Date?) -> Void

    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var assets: [PHAsset] = []
    @State private var selectedAsset: PHAsset?
    @State private var isSaving = false


    var body: some View {
        NavigationStack {
            Group {
                if authorizationStatus != .authorized && authorizationStatus != .limited {
                    photoLibraryPermissionView
                } else {
                    photoGrid
                }
            }
            .background(Color.kiroku.background.ignoresSafeArea())
            .navigationTitle("照片库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(Color.kiroku.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedAsset != nil {
                        Button("保存") {
                            saveSelectedPhoto()
                        }
                        .fontWeight(.medium)
                        .foregroundStyle(Color.kiroku.primary)
                        .disabled(isSaving)
                    }
                }
            }
            .onAppear {
                checkAuthorizationAndLoad()
            }
        }
    }

    private var photoLibraryPermissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(Color.kiroku.primary.opacity(0.6))
            Text("需要访问相册以选择照片")
                .font(.headline)
                .foregroundStyle(Color.kiroku.textPrimary)
            Text("请在设置中允许访问照片")
                .font(.subheadline)
                .foregroundStyle(Color.kiroku.textSecondary)
                .multilineTextAlignment(.center)
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                Button("打开设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.kiroku.primary)
            } else {
                Button("允许访问") {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                        DispatchQueue.main.async {
                            authorizationStatus = status
                            if status == .authorized || status == .limited {
                                loadAssets()
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.kiroku.primary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photoGrid: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 2
            let columnCount: CGFloat = 4
            let totalSpacing = spacing * (columnCount - 1)
            let cellSize = (geometry.size.width - totalSpacing) / columnCount
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: Int(columnCount)), spacing: spacing) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        PhotoLibraryThumbnailCell(
                            asset: asset,
                            cellSize: cellSize,
                            isSelected: selectedAsset?.localIdentifier == asset.localIdentifier
                        ) {
                            selectedAsset = asset
                        }
                    }
                }
                .padding(spacing)
            }
        }
    }

    private func checkAuthorizationAndLoad() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = status
        if status == .authorized || status == .limited {
            loadAssets()
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    authorizationStatus = newStatus
                    if newStatus == .authorized || newStatus == .limited {
                        loadAssets()
                    }
                }
            }
        }
    }

    private func loadAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 500
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var list: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            list.append(asset)
        }
        assets = list
    }

    private func saveSelectedPhoto() {
        guard let asset = selectedAsset else { return }
        isSaving = true
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            DispatchQueue.main.async {
                isSaving = false
                guard let data = data, let image = UIImage(data: data) else {
                    return
                }
                let date = asset.creationDate
                onPick(image, date)
            }
        }
    }
}

/// 相册网格中的缩略图单元格
private struct PhotoLibraryThumbnailCell: View {
    let asset: PHAsset
    let cellSize: CGFloat
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.kiroku.cardFill
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .frame(width: cellSize, height: cellSize)
            .clipped()
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.kiroku.primary, lineWidth: 3)
                        .padding(1)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let scale = displayScale
        let size = CGSize(width: cellSize * scale, height: cellSize * scale)
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { img, _ in
            DispatchQueue.main.async {
                image = img
            }
        }
    }
}

#Preview {
    PhotoLibraryPickerView { _, _ in }
}
