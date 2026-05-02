import Foundation
import UniformTypeIdentifiers
import UIKit

struct ImagePreparationService {
    private let maxDimension: CGFloat = 2_000
    private let compressionQuality: CGFloat = 0.82

    func prepareAttachment(for image: UIImage) throws -> AnalyzeWineMenuAttachment {
        let imageData = try prepareForUpload(image)
        return AnalyzeWineMenuAttachment(
            base64Data: imageData.base64EncodedString(),
            mimeType: "image/jpeg",
            filename: "wine-list.jpg"
        )
    }

    func prepareAttachment(from fileURL: URL) throws -> AnalyzeWineMenuAttachment {
        let didAccessSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let resourceValues = try fileURL.resourceValues(forKeys: [.contentTypeKey])
        let contentType = resourceValues.contentType

        if contentType?.conforms(to: .pdf) == true {
            guard let data = try? Data(contentsOf: fileURL), data.isEmpty == false else {
                throw WineAnalysisServiceError.invalidInput
            }

            return AnalyzeWineMenuAttachment(
                base64Data: data.base64EncodedString(),
                mimeType: "application/pdf",
                filename: fileURL.lastPathComponent
            )
        }

        if contentType?.conforms(to: .image) == true {
            return try prepareAttachment(for: loadImage(at: fileURL))
        }

        throw WineAnalysisServiceError.invalidInput
    }

    func prepareForUpload(_ image: UIImage) throws -> Data {
        let normalizedImage = normalized(image)
        let resizedImage = resizedIfNeeded(normalizedImage)

        guard let data = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            throw WineAnalysisServiceError.invalidInput
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

    private func loadImage(at fileURL: URL) throws -> UIImage {
        guard
            let data = try? Data(contentsOf: fileURL),
            let image = UIImage(data: data)
        else {
            throw WineAnalysisServiceError.invalidInput
        }

        return image
    }
}
