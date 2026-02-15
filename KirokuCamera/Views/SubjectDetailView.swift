import SwiftUI

/// 记录项详情页列表展示方式
enum SubjectListViewMode: String, CaseIterable {
    case timeline
    case grid
}

/// 记录项详情页：展示所有照片时间线
struct SubjectDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStore: DataStore
    let subject: Subject

    @State private var displayName: String = ""
    @State private var showingCamera = false
    @State private var showingCompare = false
    @State private var selectedPhoto: Photo?
    @State private var showingRenameAlert = false
    @State private var renameText = ""
    @State private var listViewMode: SubjectListViewMode = .grid

    private var subjectPhotos: [Photo] {
        dataStore.photos(for: subject.id)
    }

    private var photoCount: Int {
        subjectPhotos.count
    }

    var body: some View {
        ZStack {
            Color.kiroku.background.ignoresSafeArea()

            Group {
                if subjectPhotos.isEmpty {
                    emptyStateView
                } else {
                    photosTimelineView
                }
            }
        }
        .overlay(alignment: .leading) {
            Color.clear
                .frame(width: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width > 80 { dismiss() }
                        }
                )
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .background(SwipeBackEnabler())
        .toolbarBackground(.regularMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.kiroku.primary)
                }
                .accessibilityLabel(String(localized: "返回"))
            }
            ToolbarItem(placement: .principal) {
                Button {
                    renameText = displayName
                    showingRenameAlert = true
                } label: {
                    Text(displayName)
                        .font(.headline)
                        .foregroundStyle(Color.kiroku.textPrimary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if photoCount >= 2 {
                        Button {
                            showingCompare = true
                        } label: {
                            Image(systemName: "square.split.2x1")
                                .foregroundStyle(Color.kiroku.primary)
                        }
                    }

                    Button {
                        showingCamera = true
                    } label: {
                        Image(systemName: "camera")
                            .foregroundStyle(Color.kiroku.primary)
                    }
                }
            }
        }
        .onAppear {
            displayName = subject.name
        }
        .fullScreenCover(isPresented: $showingCamera) {
            QuickCameraView(preselectedSubject: subject)
        }
        .navigationDestination(isPresented: $showingCompare) {
            CompareView(photos: subjectPhotos)
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
        .alert("重命名记录项", isPresented: $showingRenameAlert) {
            TextField("记录项名称", text: $renameText)
            Button("取消", role: .cancel) {
                renameText = ""
            }
            Button("保存") {
                applyRename()
            }
        } message: {
            Text("请输入新名称")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(Color.kiroku.primary)

            VStack(spacing: 8) {
                Text("还没有照片")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.kiroku.textPrimary)

                Text("点击右上角相机按钮\n开始拍摄第一张照片")
                    .font(.subheadline)
                    .foregroundStyle(Color.kiroku.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(String(localized: "Continue")) {
                showingCamera = true
            }
            .buttonStyle(.kirokuPrimary)
        }
        .padding(40)
    }

    private var photosTimelineView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 0) {
                    Spacer(minLength: 0)
                    Picker("视图", selection: $listViewMode) {
                        Image(systemName: "list.bullet").tag(SubjectListViewMode.timeline)
                        Image(systemName: "square.grid.2x2").tag(SubjectListViewMode.grid)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                switch listViewMode {
                case .timeline:
                    ForEach(subjectPhotos) { photo in
                        PhotoTimelineCard(photo: photo, isCover: dataStore.coverPhoto(for: subject.id)?.id == photo.id)
                            .onTapGesture {
                                selectedPhoto = photo
                            }
                    }
                case .grid:
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(subjectPhotos) { photo in
                            PhotoGridCell(photo: photo, isCover: dataStore.coverPhoto(for: subject.id)?.id == photo.id)
                                .onTapGesture {
                                    selectedPhoto = photo
                                }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func applyRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            renameText = ""
            return
        }
        dataStore.updateSubjectName(subject, name: trimmed)
        displayName = trimmed
        renameText = ""
    }
}

// MARK: - 网格照片单元格（主体详情内）
struct PhotoGridCell: View {
    let photo: Photo
    var isCover: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 用透明占位固定 3:4，图片 overlay 填满并裁切，避免长图撑高
            Color.clear
                .aspectRatio(3/4, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topLeading) {
                    AsyncPhotoImage.fullSize(fileName: photo.fileName, contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                .overlay(alignment: .topLeading) {
                    if isCover {
                        Text("封面")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.kiroku.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(.ultraThinMaterial)
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.kiroku.background.opacity(0.65))
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.kiroku.glassBorder.opacity(0.8), lineWidth: 0.5)
                            )
                            .padding(6)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(photo.formattedDate)
                .font(.caption2)
                .foregroundStyle(Color.kiroku.textSecondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.kiroku.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.kiroku.glassBorder, lineWidth: 1)
                )
        )
    }
}

/// 时间线照片卡片 - 毛玻璃风格（主体详情内）
struct PhotoTimelineCard: View {
    let photo: Photo
    var isCover: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.kiroku.logoBlue)
                Text(photo.detailedDate)
                    .font(.subheadline)
                    .foregroundStyle(Color.kiroku.textSecondary)
                Spacer()
            }

            ZStack(alignment: .topLeading) {
                AsyncPhotoImage.fullSize(fileName: photo.fileName, contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                if isCover {
                    Text("封面")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.kiroku.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.kiroku.background.opacity(0.65))
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.kiroku.glassBorder.opacity(0.8), lineWidth: 0.5)
                        )
                        .padding(8)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3/4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.kiroku.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.kiroku.glassBorder, lineWidth: 1)
                )
                .shadow(color: Color.kiroku.shadow, radius: 12, x: 0, y: 6)
        )
    }
}

#Preview {
    NavigationStack {
        SubjectDetailView(subject: Subject(name: "Amy的屁股"))
            .environmentObject(DataStore())
    }
}
