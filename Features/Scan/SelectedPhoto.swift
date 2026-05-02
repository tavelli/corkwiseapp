import CoreTransferable
import Foundation
import UIKit
import UniformTypeIdentifiers

struct SelectedPhoto: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw WineAnalysisServiceError.invalidInput
            }

            return SelectedPhoto(image: image)
        }
    }
}
