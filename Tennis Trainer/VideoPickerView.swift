import SwiftUI
import PhotosUI

struct VideoPickerView: UIViewControllerRepresentable {
    let request: UUID
    let importer: VideoImportManager
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPickerView
        
        init(_ parent: VideoPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let provider: VideoImportManager.Provider? = results.first.map { result in
                { completion in
                    result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie", completionHandler: completion)
                }
            }
            parent.importer.receiveSelection(request: parent.request, provider: provider)
            // Normal selection dismissal does not cancel its provider operation.
            parent.dismiss()
        }
    }
}
