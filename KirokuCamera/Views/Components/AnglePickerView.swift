import SwiftUI

/// 记录项选择器：用于拍照后选择保存到哪个记录项
struct SubjectPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStore: DataStore

    let image: UIImage
    let preselectedSubject: Subject?
    let selectedDate: Date
    let onSave: (Subject) async -> Bool
    let onDiscard: () -> Void

    @State private var showingNewSubjectInput = false
    @State private var newSubjectName = ""
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""

    private var subjects: [Subject] {
        dataStore.sortedSubjects()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kiroku.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    photoPreview
                    Divider()
                        .background(Color.kiroku.divider)
                    subjectSelectionList
                }
                .disabled(isSaving)
                .blur(radius: isSaving ? 1 : 0)

                if isSaving {
                    savingOverlay
                }
            }
            .navigationTitle("选择记录项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("放弃") {
                        guard !isSaving else { return }
                        dismiss()
                        onDiscard()
                    }
                    .foregroundStyle(.red)
                    .disabled(isSaving)
                }
            }
            .alert("添加记录项", isPresented: $showingNewSubjectInput) {
                TextField("记录项名称", text: $newSubjectName)
                Button("取消", role: .cancel) {
                    newSubjectName = ""
                }
                Button("创建并保存") {
                    createNewSubjectAndSave()
                }
            } message: {
                Text("例如：Amy的屁股")
            }
            .alert("保存失败", isPresented: $showingSaveError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
            .task { @MainActor in
                if let subject = preselectedSubject {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await startSave(subject)
                }
            }
        }
    }

    private var photoPreview: some View {
        VStack(spacing: 8) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: selectedDate)
    }

    private var subjectSelectionList: some View {
        List {
            if !subjects.isEmpty {
                Section("已有记录项") {
                    ForEach(subjects) { subject in
                        subjectRow(subject: subject)
                    }
                }
            }
            Section {
                Button {
                    showingNewSubjectInput = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("添加记录项")
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text("开始记录新的变化")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.kiroku.cardFill)
    }

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                Text("保存中...")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .padding(24)
            .background(Color.kiroku.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func subjectRow(subject: Subject) -> some View {
        Button {
            Task { @MainActor in
                await startSave(subject)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(subject.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("\(dataStore.photoCount(for: subject.id)) 张照片")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func createNewSubjectAndSave() {
        let name = newSubjectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            newSubjectName = ""
            return
        }
        let subject: Subject
        if let existing = subjects.first(where: { $0.name == name }) {
            subject = existing
        } else {
            subject = Subject(name: name)
            dataStore.addSubject(subject)
        }
        newSubjectName = ""
        Task { @MainActor in
            await startSave(subject)
        }
    }

    @MainActor
    private func startSave(_ subject: Subject) async {
        guard !isSaving else { return }
        isSaving = true
        let success = await onSave(subject)
        isSaving = false
        if !success {
            saveErrorMessage = String(localized: "保存失败，请重试。")
            showingSaveError = true
        }
    }
}

#Preview {
    SubjectPickerView(
        image: UIImage(systemName: "photo")!,
        preselectedSubject: nil,
        selectedDate: Date(),
        onSave: { _ in true },
        onDiscard: { }
    )
    .environmentObject(DataStore())
}
