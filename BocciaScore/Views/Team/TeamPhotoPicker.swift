import PhotosUI
import SwiftUI

/// "Foto hinzufügen / ändern" for the logged-in team, like on the website's team page:
/// picks a photo from the library and uploads it as a square JPEG.
struct TeamPhotoPicker: View {
    let team: Team
    /// Called after a successful upload, for screens that hold their own copy of the team.
    var onUploaded: () async -> Void = {}

    @Environment(AppModel.self) private var model
    @State private var selection: PhotosPickerItem?
    @State private var isUploading = false
    @State private var error: APIError?

    var body: some View {
        // PhotosPicker's label closure is @Sendable, so it only captures plain values.
        let label = PickerLabel(isUploading: isUploading, hasPhoto: team.photoUrl != nil)
        PhotosPicker(selection: $selection, matching: .images, preferredItemEncoding: .compatible) { label }
        .disabled(isUploading)
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
        .alert("Foto nicht gespeichert", isPresented: .constant(error != nil), presenting: error) { _ in
            Button("OK") { error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        isUploading = true
        defer {
            isUploading = false
            selection = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                throw APIError(code: "invalid_photo", status: nil, serverMessage: nil)
            }
            try await model.uploadPhoto(image)
            await onUploaded()
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = APIError(code: "invalid_photo", status: nil, serverMessage: nil)
        }
    }
}

private struct PickerLabel: View {
    let isUploading: Bool
    let hasPhoto: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isUploading {
                ProgressView()
            } else {
                Image(systemName: "camera.fill")
            }
            Text(isUploading ? "Foto wird hochgeladen …" : hasPhoto ? "Foto ändern" : "Foto hinzufügen")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.qualifier)
    }
}
