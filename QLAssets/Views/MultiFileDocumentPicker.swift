import SwiftUI
import UIKit
import UniformTypeIdentifiers


struct MultiFileDocumentPicker:
    UIViewControllerRepresentable {

    let contentTypes:
        [UTType]

    let onPick:
        ([URL]) -> Void

    let onCancel:
        () -> Void


    func makeUIViewController(
        context:
            Context
    ) -> UIDocumentPickerViewController {

        let picker =
            UIDocumentPickerViewController(
                forOpeningContentTypes:
                    contentTypes,
                asCopy:
                    true
            )

        picker.delegate =
            context.coordinator

        picker.allowsMultipleSelection =
            true

        picker.shouldShowFileExtensions =
            true

        return picker
    }


    func updateUIViewController(
        _ uiViewController:
            UIDocumentPickerViewController,
        context:
            Context
    ) {

    }


    func makeCoordinator()
        -> Coordinator {

        Coordinator(
            onPick:
                onPick,
            onCancel:
                onCancel
        )
    }


    final class Coordinator:
        NSObject,
        UIDocumentPickerDelegate {

        let onPick:
            ([URL]) -> Void

        let onCancel:
            () -> Void


        init(
            onPick:
                @escaping ([URL]) -> Void,
            onCancel:
                @escaping () -> Void
        ) {

            self.onPick =
                onPick

            self.onCancel =
                onCancel
        }


        func documentPicker(
            _ controller:
                UIDocumentPickerViewController,
            didPickDocumentsAt urls:
                [URL]
        ) {

            onPick(
                urls
            )
        }


        func documentPickerWasCancelled(
            _ controller:
                UIDocumentPickerViewController
        ) {

            onCancel()
        }
    }
}
