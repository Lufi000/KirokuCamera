import SwiftUI

/// 相册列表展示方式
enum HomeListViewMode: String, CaseIterable {
    case list
    case grid
}

/// 首页：显示所有记录项列表
struct HomeView: View {
    @EnvironmentObject private var dataStore: DataStore

    @State private var showingCamera = false
    @State private var showingDeleteConfirm = false
    @State private var subjectToDelete: Subject?
    @State private var showingRenameAlert = false
    @State private var subjectToRename: Subject?
    @State private var renameText = ""
    @State private var listViewMode: HomeListViewMode = .grid

    private var subjects: [Subject] {
        dataStore.sortedSubjects()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kiroku.background.ignoresSafeArea()

                Group {
                    if subjects.isEmpty {
                        emptyStateView
                    } else {
                        subjectListView
                    }
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingCameraButton
                    }
                }
            }
            .navigationTitle("相册列表")
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .fullScreenCover(isPresented: $showingCamera) {
                QuickCameraView()
            }
            .alert("删除记录项", isPresented: $showingDeleteConfirm) {
                Button("取消", role: .cancel) {
                    subjectToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let subject = subjectToDelete {
                        dataStore.deleteSubject(subject)
                        subjectToDelete = nil
                    }
                }
            } message: {
                Text(deleteConfirmMessage)
            }
            .alert("重命名记录项", isPresented: $showingRenameAlert) {
                TextField("记录项名称", text: $renameText)
                Button("取消", role: .cancel) {
                    subjectToRename = nil
                    renameText = ""
                }
                Button("保存") {
                    applyRename()
                }
            } message: {
                Text("请输入新名称")
            }
        }
        .tint(Color.kiroku.primary)
    }

    private var deleteConfirmMessage: String {
        guard let subject = subjectToDelete else { return "" }
        let count = dataStore.photoCount(for: subject.id)
        return "确定要删除「\(subject.name)」吗？\n将同时删除 \(count) 张照片，此操作无法撤销。"
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(Color.kiroku.primary)

            VStack(spacing: 8) {
                Text("开始记录变化")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.kiroku.textPrimary)

                Text("点击下方相机按钮开始拍照\n拍完后选择保存的记录项和角度")
                    .font(.subheadline)
                    .foregroundStyle(Color.kiroku.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("开始拍照") {
                showingCamera = true
            }
            .buttonStyle(.kirokuPrimary)
        }
        .padding(40)
    }

    private var subjectListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !subjects.isEmpty {
                    HStack(alignment: .center, spacing: 0) {
                        Spacer(minLength: 0)
                        Picker("视图", selection: $listViewMode) {
                            Image(systemName: "list.bullet").tag(HomeListViewMode.list)
                            Image(systemName: "square.grid.2x2").tag(HomeListViewMode.grid)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Group {
                    switch listViewMode {
                    case .list:
                        LazyVStack(spacing: 12) {
                            ForEach(subjects) { subject in
                                subjectRowLink(subject: subject)
                            }
                        }
                    case .grid:
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(subjects) { subject in
                                subjectGridLink(subject: subject)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func subjectRowLink(subject: Subject) -> some View {
        NavigationLink(destination: SubjectDetailView(subject: subject)) {
            SubjectRowView(subject: subject, dataStore: dataStore)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                subjectToDelete = subject
                showingDeleteConfirm = true
            } label: { Label("删除", systemImage: "trash") }
            Button { beginRename(subject) } label: { Label("重命名", systemImage: "pencil") }
                .tint(Color.kiroku.primary)
        }
        .contextMenu {
            Button { beginRename(subject) } label: { Label("重命名", systemImage: "pencil") }
            Button(role: .destructive) {
                subjectToDelete = subject
                showingDeleteConfirm = true
            } label: { Label("删除", systemImage: "trash") }
        }
    }

    private func subjectGridLink(subject: Subject) -> some View {
        NavigationLink(destination: SubjectDetailView(subject: subject)) {
            SubjectGridCell(subject: subject, dataStore: dataStore)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { beginRename(subject) } label: { Label("重命名", systemImage: "pencil") }
            Button(role: .destructive) {
                subjectToDelete = subject
                showingDeleteConfirm = true
            } label: { Label("删除", systemImage: "trash") }
        }
    }

    /// 右下角「打开相机」浮动按钮（磨砂紫玻璃质感）
    private var floatingCameraButton: some View {
        Button {
            showingCamera = true
        } label: {
            ZStack {
                // 1. 紫色底：饱和渐变
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.kiroku.primary.opacity(0.85),
                                Color.kiroku.primary
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 60, height: 60)
                
                // 2. 边缘厚度环：内侧一圈深色描边，模拟玻璃边缘的折射厚度
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.kiroku.primary.opacity(0.3),
                                Color.kiroku.primary.opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 60, height: 60)
                
                // 3. 毛玻璃层：叠在紫色上，产生磨砂质感
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
                
                // 4. 补紫色饱和度（磨砂后颜色会变淡，补回来）
                Circle()
                    .fill(Color.kiroku.primary.opacity(0.4))
                    .frame(width: 60, height: 60)
                
                // 5. 顶部弧形高光：玻璃反光感
                Circle()
                    .trim(from: 0, to: 0.5)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: 54, height: 54)
                
                // 6. 相机图标
                Image(systemName: "camera.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
            }
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    private func beginRename(_ subject: Subject) {
        subjectToRename = subject
        renameText = subject.name
        showingRenameAlert = true
    }

    private func applyRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let subject = subjectToRename, !trimmed.isEmpty else {
            subjectToRename = nil
            renameText = ""
            return
        }
        dataStore.updateSubjectName(subject, name: trimmed)
        subjectToRename = nil
        renameText = ""
    }
}

/// 记录项网格单元格（相册列表网格视图）
struct SubjectGridCell: View {
    let subject: Subject
    @ObservedObject var dataStore: DataStore

    private let cornerRadius: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color.kiroku.cardFill
                if let cover = dataStore.coverPhoto(for: subject.id) {
                    AsyncPhotoImage.thumbnail(fileName: cover.fileName, size: 200)
                        .scaledToFit()
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.title)
                        .foregroundStyle(Color.kiroku.primary.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3/4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 4))

            Text(subject.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.kiroku.textPrimary)
                .lineLimit(1)
            Text("\(dataStore.photoCount(for: subject.id)) 张")
                .font(.caption)
                .foregroundStyle(Color.kiroku.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.kiroku.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.kiroku.glassBorder, lineWidth: 1)
                )
                .shadow(color: Color.kiroku.shadow, radius: 8, x: 0, y: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// 记录项行视图 - 毛玻璃卡片样式
struct SubjectRowView: View {
    let subject: Subject
    @ObservedObject var dataStore: DataStore

    var body: some View {
        HStack(spacing: 16) {
            if let cover = dataStore.coverPhoto(for: subject.id) {
                AsyncPhotoImage.thumbnail(fileName: cover.fileName, size: 120)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.kiroku.cardFill)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundStyle(Color.kiroku.primary.opacity(0.5))
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(subject.name)
                    .font(.headline)
                    .foregroundStyle(Color.kiroku.textPrimary)
                Text("\(dataStore.photoCount(for: subject.id)) 张照片")
                    .font(.subheadline)
                    .foregroundStyle(Color.kiroku.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.kiroku.textSecondary)
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
    HomeView()
        .environmentObject(DataStore())
}
