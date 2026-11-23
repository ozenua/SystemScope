import Core
import DesignSystem
import DeviceInfo
import QuickLook
import SwiftUI
import UniformTypeIdentifiers
import UIKit

public struct StorageManagerView: View {
    private let onBack: () -> Void
    @State private var model: StorageManagerViewModel
    @State private var isDocumentPickerPresented = false
    @State private var isPhotoReviewPresented = false
    @State private var isDocumentReviewPresented = false
    @State private var isCacheConfirmationPresented = false
    @State private var previewItem: DocumentStorageItem?

    public init(
        model: StorageManagerViewModel,
        onBack: @escaping () -> Void
    ) {
        self.onBack = onBack
        _model = State(initialValue: model)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                storageOverview
                photosSection
                documentsSection
                cacheSection
                appStorageGuidance
                if let status = model.statusMessage {
                    messageCard(status, color: SSColor.textSubtle)
                }
                if let error = model.errorMessage {
                    messageCard(error, color: SSColor.errorText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(SSScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
        .task { model.load() }
        .sheet(isPresented: $isDocumentPickerPresented) {
            StorageDocumentPicker { urls in
                Task { await model.analyzeDocuments(at: urls) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isPhotoReviewPresented) {
            PhotoDeletionReview(items: model.selectedPhotoItems) {
                Task { await model.deleteSelectedPhotos() }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isDocumentReviewPresented) {
            DocumentDeletionReview(items: model.documentItems) {
                Task { await model.deleteSelectedDocuments() }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $previewItem) { item in
            StorageQuickLookPreview(item: item)
                .ignoresSafeArea()
        }
        .confirmationDialog(
            "Clear SystemScope cache?",
            isPresented: $isCacheConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Clear cache", role: .destructive) {
                model.clearCache()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only disposable files in SystemScope's designated cache folders will be removed. Documents and personal data are not included.")
        }
        .alert("Storage manager", isPresented: errorPresented) {
            Button("OK", role: .cancel) { model.dismissError() }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            SSBackButton(label: "Back", action: onBack)
                .padding(.leading, -6)
            VStack(alignment: .leading, spacing: 6) {
                Text("Storage manager")
                    .ssText(.screenTitle24)
                    .foregroundStyle(SSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Review your device storage and choose what SystemScope may remove.")
                    .ssText(.bodyMedium14)
                    .foregroundStyle(SSColor.textSubtle)
            }
        }
    }

    private var storageOverview: some View {
        sectionCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Device storage")
                    .ssText(.metric17)
                    .foregroundStyle(SSColor.textStrong)
                Spacer()
                if model.isRefreshingStorage {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Refresh") { model.refreshStorage() }
                        .ssText(.caption13)
                        .foregroundStyle(SSColor.accent)
                }
            }

            if let storage = model.storage {
                if let utilization = storage.utilization {
                    ProgressView(value: utilization)
                        .tint(SSColor.accent)
                        .accessibilityLabel("Storage used")
                        .accessibilityValue("\(Int(utilization * 100)) percent")
                }
                HStack(alignment: .top, spacing: 8) {
                    capacityMetric(title: "Used", bytes: storage.usedBytes)
                    Spacer(minLength: 4)
                    capacityMetric(title: "Available", bytes: storage.availableBytes)
                    Spacer(minLength: 4)
                    capacityMetric(title: "Total", bytes: storage.totalBytes)
                }
                if model.storageRefreshFailed {
                    Text("The last storage refresh failed; these readings may be outdated.")
                        .ssText(.caption12)
                        .foregroundStyle(SSColor.statusAmber)
                }
            } else {
                Text("Storage capacity is unavailable on this device.")
                    .ssText(.body14)
                    .foregroundStyle(SSColor.textSubtle)
            }
        }
    }

    private var photosSection: some View {
        sectionCard {
            sectionHeading("Photos and videos", subtitle: "Only items available through your Photos access are scanned.")
            if model.photoAccess == .limited {
                Text("Limited Photos access is active. The scan includes only the items you selected in iOS.")
                    .ssText(.caption13)
                    .foregroundStyle(SSColor.textSubtle)
            } else if model.photoAccess == .denied || model.photoAccess == .restricted {
                Text("Photos access is unavailable. You can enable it in SystemScope settings.")
                    .ssText(.caption13)
                    .foregroundStyle(SSColor.textSubtle)
                Button("Open SystemScope settings", action: openAppSettings)
                    .buttonStyle(.ssSecondaryCompact)
            }

            Button {
                Task { await model.scanPhotos() }
            } label: {
                HStack(spacing: 8) {
                    if model.isScanningPhotos { ProgressView().tint(.white) }
                    Text(model.isScanningPhotos ? "Scanning Photos…" : "Scan Photos")
                }
            }
            .buttonStyle(.ssPrimary)
            .disabled(model.isScanningPhotos)

            if let progress = model.photoScanProgress {
                ProgressView(value: Double(progress.completed), total: Double(max(1, progress.total)))
                Text("Checking \(progress.completed) of \(progress.total) accessible items")
                    .ssText(.caption12)
                    .foregroundStyle(SSColor.textSubtle)
            }

            if model.photoUnreadableCount > 0 {
                Text("\(model.photoUnreadableCount) Photos assets could not be measured; they are excluded from size results.")
                    .ssText(.caption12)
                    .foregroundStyle(SSColor.statusAmber)
            }

            if !model.largeMedia.isEmpty {
                sectionHeading("Large photos and videos", subtitle: "Large images are 20 MB or more; large videos are 100 MB or more.")
                ForEach(model.largeMedia) { item in
                    photoRow(item, note: mediaDescription(item))
                }
            } else if model.photoAccess == .authorized || model.photoAccess == .limited,
                      !model.isScanningPhotos, model.photoMatches.isEmpty {
                Text("No large items or similar photos found in the accessible library.")
                    .ssText(.caption13)
                    .foregroundStyle(SSColor.textSubtle)
            }

            if !model.photoMatches.isEmpty {
                sectionHeading("Duplicate and similar photos", subtitle: "Photo comparisons use image features after matching dimensions and capture time.")
                ForEach(model.photoMatches) { match in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(match.kind == .duplicate ? "Possible duplicate" : "Visually similar")
                                .ssText(.labelSemibold14)
                                .foregroundStyle(SSColor.textStrong)
                            Spacer()
                            Text(ByteFormatting.storage(match.potentialSpaceBytes))
                                .ssText(.caption13)
                                .foregroundStyle(SSColor.textSubtle)
                        }
                        photoRow(match.first, note: "First · \(mediaDescription(match.first))")
                        photoRow(match.second, note: "Second · \(mediaDescription(match.second))")
                    }
                    .padding(12)
                    .background(SSColor.surfaceSubtle, in: RoundedRectangle(cornerRadius: 16))
                }
            }

            if model.photoUncomparableCount > 0 {
                Text("\(model.photoUncomparableCount) image comparisons were unavailable.")
                    .ssText(.caption12)
                    .foregroundStyle(SSColor.statusAmber)
            }

            if !model.selectedPhotoIDs.isEmpty {
                Button("Review \(model.selectedPhotoIDs.count) selected") {
                    isPhotoReviewPresented = true
                }
                .buttonStyle(.ssSecondary)
            }
        }
    }

    private var documentsSection: some View {
        sectionCard {
            sectionHeading("Large files", subtitle: "Choose files or folders in Files. SystemScope scans only those locations.")
            Button {
                isDocumentPickerPresented = true
            } label: {
                HStack(spacing: 8) {
                    if model.isScanningDocuments { ProgressView().tint(.white) }
                    Text(model.isScanningDocuments ? "Analyzing files…" : "Choose files or folders")
                }
            }
            .buttonStyle(.ssPrimary)
            .disabled(model.isScanningDocuments)

            if let scan = model.documentScan {
                if scan.unreadableFileCount > 0 {
                    Text("\(scan.unreadableFileCount) selected files could not be read.")
                        .ssText(.caption12)
                        .foregroundStyle(SSColor.statusAmber)
                }
                if !scan.selectedLocations.isEmpty {
                    sectionHeading("Selected locations", subtitle: "Folders are scanned for sizes; only explicitly selected files can be deleted.")
                    ForEach(scan.selectedLocations) { item in
                        if item.isDirectory {
                            folderSummary(item)
                        } else {
                            documentRow(item, note: item.typeDescription) { previewItem = item }
                        }
                    }
                }
                let largeFiles = scan.files.filter(\.isLarge)
                if !largeFiles.isEmpty {
                    sectionHeading("Large files", subtitle: "Files of 100 MB or more in selected locations.")
                    ForEach(largeFiles) { item in
                        documentRow(item, note: item.typeDescription) { previewItem = item }
                    }
                } else if scan.files.isEmpty {
                    Text("No readable files were found in the selected locations.")
                        .ssText(.caption13)
                        .foregroundStyle(SSColor.textSubtle)
                } else {
                    Text("No files of 100 MB or more were found.")
                        .ssText(.caption13)
                        .foregroundStyle(SSColor.textSubtle)
                }

                if !scan.duplicateGroups.isEmpty {
                    sectionHeading("Duplicate files", subtitle: "Duplicates are identified by matching SHA-256 content hashes.")
                    ForEach(scan.duplicateGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Potential space: \(ByteFormatting.storage(group.potentialSpaceBytes))")
                                .ssText(.caption13)
                                .foregroundStyle(SSColor.textSubtle)
                            ForEach(group.files) { item in
                                documentRow(item, note: item.typeDescription) { previewItem = item }
                            }
                        }
                        .padding(12)
                        .background(SSColor.surfaceSubtle, in: RoundedRectangle(cornerRadius: 16))
                    }
                }

                if !model.selectedDocumentIDs.isEmpty {
                    Button("Review \(model.selectedDocumentIDs.count) selected") {
                        isDocumentReviewPresented = true
                    }
                    .buttonStyle(.ssSecondary)
                }
            }
        }
    }

    private var cacheSection: some View {
        sectionCard {
            sectionHeading("SystemScope cache", subtitle: "Only designated disposable cache and temporary files are included.")
            HStack {
                Label("Cache files", systemImage: "externaldrive")
                    .ssText(.bodyMedium14)
                    .foregroundStyle(SSColor.textStrong)
                Spacer()
                if let cacheUsage = model.cacheUsage {
                    Text("\(ByteFormatting.storage(cacheUsage.byteCount)) · \(cacheUsage.fileCount) files")
                        .ssText(.caption13)
                        .foregroundStyle(SSColor.textSubtle)
                } else {
                    Text("Unavailable")
                        .ssText(.caption13)
                        .foregroundStyle(SSColor.textSubtle)
                }
            }
            Button("Clear SystemScope cache", role: .destructive) {
                isCacheConfirmationPresented = true
            }
            .buttonStyle(.ssSecondary)
            .disabled((model.cacheUsage?.byteCount ?? 0) == 0)
        }
    }

    private var appStorageGuidance: some View {
        sectionCard {
            sectionHeading("Manage other apps", subtitle: "iOS does not let SystemScope inspect or clear another app's private storage.")
            Text("To manage individual apps, open Settings → General → iPhone Storage. Apple does not provide a public link that opens that specific Settings page.")
                .ssText(.body14)
                .foregroundStyle(SSColor.textSubtle)
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .ssText(.metric17)
                .foregroundStyle(SSColor.textStrong)
            Text(subtitle)
                .ssText(.caption13)
                .foregroundStyle(SSColor.textSubtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func capacityMetric(title: String, bytes: Int64) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ByteFormatting.storage(bytes))
                .ssText(.labelSemibold14)
                .foregroundStyle(SSColor.textStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .ssText(.caption12)
                .foregroundStyle(SSColor.textSubtle)
        }
    }

    private func photoRow(_ item: PhotoMediaItem, note: String) -> some View {
        Button {
            model.togglePhotoSelection(item)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: model.selectedPhotoIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(model.selectedPhotoIDs.contains(item.id) ? SSColor.accent : SSColor.textTertiary)
                    .font(.system(size: 20))
                Image(systemName: item.mediaType == .video ? "video" : "photo")
                    .foregroundStyle(SSColor.textSubtle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.mediaType == .video ? "Video · \(ByteFormatting.storage(item.byteSize))" : "Photo · \(ByteFormatting.storage(item.byteSize))")
                        .ssText(.labelSemibold14)
                        .foregroundStyle(SSColor.textStrong)
                    Text(note)
                        .ssText(.caption12)
                        .foregroundStyle(SSColor.textSubtle)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(item.mediaType.rawValue), \(ByteFormatting.storage(item.byteSize))")
        .accessibilityAddTraits(model.selectedPhotoIDs.contains(item.id) ? .isSelected : [])
    }

    private func documentRow(
        _ item: DocumentStorageItem,
        note: String,
        onPreview: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                model.toggleDocumentSelection(item)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: model.selectedDocumentIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(model.selectedDocumentIDs.contains(item.id) ? SSColor.accent : SSColor.textTertiary)
                        .font(.system(size: 20))
                    Image(systemName: "doc")
                        .foregroundStyle(SSColor.textSubtle)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.filename)
                            .ssText(.labelSemibold14)
                            .foregroundStyle(SSColor.textStrong)
                            .lineLimit(1)
                        Text("\(note) · \(ByteFormatting.storage(item.byteSize))")
                            .ssText(.caption12)
                            .foregroundStyle(SSColor.textSubtle)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(item.filename), \(ByteFormatting.storage(item.byteSize))")
            .accessibilityAddTraits(model.selectedDocumentIDs.contains(item.id) ? .isSelected : [])

            Button(action: onPreview) {
                Image(systemName: "eye")
                    .foregroundStyle(SSColor.accent)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview \(item.filename)")
        }
    }

    private func folderSummary(_ item: DocumentStorageItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .foregroundStyle(SSColor.textSubtle)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.filename)
                    .ssText(.labelSemibold14)
                    .foregroundStyle(SSColor.textStrong)
                    .lineLimit(1)
                Text("\(item.fileCount) files · \(ByteFormatting.storage(item.byteSize))")
                    .ssText(.caption12)
                    .foregroundStyle(SSColor.textSubtle)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func mediaDescription(_ item: PhotoMediaItem) -> String {
        let duration = item.duration.map { " · \(Int($0)) sec" } ?? ""
        let date = item.date.map {
            " · \($0.formatted(date: .abbreviated, time: .shortened))"
        } ?? ""
        return "\(item.dimensions)\(duration)\(date)"
    }

    private func messageCard(_ message: String, color: Color) -> some View {
        Text(message)
            .ssText(.caption13)
            .foregroundStyle(color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SSColor.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.dismissError() } }
        )
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct PhotoDeletionReview: View {
    let items: [PhotoMediaItem]
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmationPresented = false

    var body: some View {
        SSBottomSheetChrome {
            VStack(alignment: .leading, spacing: 14) {
                SSBottomSheetTitleRow(title: "Review Photos") { dismiss() }
                Text("Review \(items.count) selected item(s), totaling \(ByteFormatting.storage(items.reduce(0) { $0 + $1.byteSize })). Delete only after confirming below.")
                    .ssText(.body14)
                    .foregroundStyle(SSColor.textSubtle)
                    .padding(.horizontal, 20)
                List(items) { item in
                    HStack {
                        Image(systemName: item.mediaType == .video ? "video" : "photo")
                        Text(item.mediaType == .video ? "Video" : "Photo")
                        Spacer()
                        Text(ByteFormatting.storage(item.byteSize))
                    }
                    .ssText(.caption13)
                }
                .listStyle(.plain)
                Button("Delete selected from Photos", role: .destructive) {
                    isConfirmationPresented = true
                }
                .buttonStyle(.ssPrimary)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .confirmationDialog(
            "Delete these Photos items?",
            isPresented: $isConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete \(items.count) selected", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the selected items from the Photos library. iOS may keep them in Recently Deleted.")
        }
    }
}

private struct DocumentDeletionReview: View {
    let items: [DocumentStorageItem]
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmationPresented = false

    var body: some View {
        SSBottomSheetChrome {
            VStack(alignment: .leading, spacing: 14) {
                SSBottomSheetTitleRow(title: "Review Files") { dismiss() }
                Text("Review \(items.count) selected file(s), totaling \(ByteFormatting.storage(items.reduce(0) { $0 + $1.byteSize })). Only selected files will be removed.")
                    .ssText(.body14)
                    .foregroundStyle(SSColor.textSubtle)
                    .padding(.horizontal, 20)
                List(items) { item in
                    HStack {
                        Image(systemName: "doc")
                        Text(item.filename).lineLimit(1)
                        Spacer()
                        Text(ByteFormatting.storage(item.byteSize))
                    }
                    .ssText(.caption13)
                }
                .listStyle(.plain)
                Button("Delete selected files", role: .destructive) {
                    isConfirmationPresented = true
                }
                .buttonStyle(.ssPrimary)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .confirmationDialog(
            "Delete selected files?",
            isPresented: $isConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete \(items.count) selected", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the selected files from their authorized locations.")
        }
    }
}

private struct StorageDocumentPicker: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item, .folder],
            asCopy: false
        )
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

private struct StorageQuickLookPreview: UIViewControllerRepresentable {
    let item: DocumentStorageItem

    func makeCoordinator() -> Coordinator {
        Coordinator(item: item)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        context.coordinator.startAccess()
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    static func dismantleUIViewController(_ controller: QLPreviewController, coordinator: Coordinator) {
        coordinator.stopAccess()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        private let item: DocumentStorageItem
        private var hasSecurityAccess = false

        init(item: DocumentStorageItem) {
            self.item = item
        }

        func startAccess() {
            hasSecurityAccess = item.securityScopedRoot.startAccessingSecurityScopedResource()
        }

        func stopAccess() {
            if hasSecurityAccess {
                item.securityScopedRoot.stopAccessingSecurityScopedResource()
                hasSecurityAccess = false
            }
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            item.url as NSURL
        }
    }
}
