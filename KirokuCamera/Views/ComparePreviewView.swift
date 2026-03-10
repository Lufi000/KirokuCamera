import SwiftUI

/// 对比图预览视图：全屏展示合成后的对比图，支持保存到相册
struct ComparePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let previewImage: UIImage
    @State private var saveResult: SaveResult?

    enum SaveResult: Identifiable {
        case success
        case failure(String)
        var id: String {
            switch self {
            case .success: return "success"
            case .failure(let msg): return "failure-\(msg)"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: previewImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(.horizontal, 16)

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.top, 8)

                Spacer()

                Button {
                    saveToPhotoLibrary()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 17, weight: .semibold))
                        Text("保存到相册")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.kiroku.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .alert(item: $saveResult) { result in
            Alert(
                title: Text(result.title),
                message: Text(result.message),
                dismissButton: .default(Text("确定")) {
                    if case .success = result {
                        dismiss()
                    }
                }
            )
        }
    }

    private func saveToPhotoLibrary() {
        CompareImageService.saveToPhotoLibrary(previewImage) { success, errorMessage in
            if success {
                saveResult = .success
            } else {
                saveResult = .failure(errorMessage ?? "保存失败")
            }
        }
    }
}

extension ComparePreviewView.SaveResult {
    var title: String {
        switch self {
        case .success: return "保存成功"
        case .failure: return "保存失败"
        }
    }

    var message: String {
        switch self {
        case .success: return "对比图已保存到相册"
        case .failure(let msg): return msg
        }
    }
}

#Preview {
    ComparePreviewView(previewImage: UIImage(systemName: "photo")!)
}
