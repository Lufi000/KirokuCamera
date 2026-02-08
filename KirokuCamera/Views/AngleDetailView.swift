import SwiftUI

/// 照片详情视图：查看大图、备注、设为封面
struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStore: DataStore
    let photo: Photo

    @State private var showingDeleteAlert = false
    @State private var noteText: String = ""
    @State private var displayedNote: String = ""
    @State private var isEditingNote = false
    @State private var hasNoteChanges = false

    private var subject: Subject? {
        photo.subjectId.flatMap { id in dataStore.subjects.first { $0.id == id } }
    }

    private var isCurrentCover: Bool {
        guard let sub = subject else { return false }
        return dataStore.coverPhoto(for: sub.id)?.id == photo.id
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kiroku.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center) {
                            if let _ = subject {
                                if isCurrentCover {
                                    Text("封面照片")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.kiroku.textSecondary)
                                } else {
                                    Button("设为封面") {
                                        setAsCover()
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(Color.kiroku.primary)
                                }
                            }
                            Spacer()
                            Text(photo.detailedDate)
                                .font(.subheadline)
                                .foregroundStyle(Color.kiroku.textSecondary)
                        }
                        .padding(.horizontal)

                        AsyncPhotoImage.fullSize(fileName: photo.fileName)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 8) {
                            if isEditingNote {
                                HStack {
                                    Spacer()
                                    Button("保存") {
                                        saveNote()
                                        isEditingNote = false
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.kiroku.primary)
                                }
                            }
                            if isEditingNote {
                                TextEditor(text: $noteText)
                                    .font(.body)
                                    .frame(minHeight: 80)
                                    .scrollContentBackground(.hidden)
                                    .tint(Color.kiroku.primary)
                                    .onChange(of: noteText) { _ in hasNoteChanges = true }
                            } else {
                                Button {
                                    noteText = displayedNote
                                    isEditingNote = true
                                } label: {
                                    Group {
                                        if !displayedNote.isEmpty {
                                            Text(displayedNote)
                                                .foregroundStyle(Color.kiroku.textPrimary)
                                        } else {
                                            Text("点击添加备注")
                                                .foregroundStyle(Color.kiroku.textSecondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        if isEditingNote { saveNote() }
                        dismiss()
                    }
                    .foregroundStyle(Color.kiroku.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .onAppear {
                let note = photo.note ?? ""
                noteText = note
                displayedNote = note
            }
            .onDisappear {
                if isEditingNote { saveNote() }
            }
            .alert("删除照片", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deletePhoto()
                }
            } message: {
                Text("确定要删除这张照片吗？此操作无法撤销。")
            }
        }
        .tint(Color.kiroku.primary)
    }

    private func saveNote() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        dataStore.updatePhotoNote(photo, note: trimmed.isEmpty ? nil : trimmed)
        displayedNote = trimmed
        hasNoteChanges = false
    }

    private func setAsCover() {
        guard let sub = subject else { return }
        dataStore.updateSubjectCover(sub, coverPhotoId: photo.id)
    }

    private func deletePhoto() {
        dataStore.deletePhoto(photo)
        dismiss()
    }
}

#Preview {
    PhotoDetailView(photo: Photo(fileName: "test.jpg", subjectId: nil, takenAt: Date()))
        .environmentObject(DataStore())
}
