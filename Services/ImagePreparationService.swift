import Foundation
import UIKit

struct ImagePreparationService {
    private let maxDimension: CGFloat = 2_000
    private let compressionQuality: CGFloat = 0.82

    func prepareForUpload(_ image: UIImage) throws -> Data {
        let normalizedImage = normalized(image)
        let resizedImage = resizedIfNeeded(normalizedImage)

        guard let data = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            throw WineAnalysisServiceError.invalidImage
        }

        return data
    }

    private func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else {
            return image
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private func resizedIfNeeded(_ image: UIImage) -> UIImage {
        let size = image.size
        let largestDimension = max(size.width, size.height)

        guard largestDimension > maxDimension else {
            return image
        }

        let scale = maxDimension / largestDimension
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
