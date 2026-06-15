import SwiftUI

enum PhosphorIcon: String, CaseIterable {
    case arrowRight = "arrow-right"
    case arrowsSplit = "arrows-split"
    case binoculars
    case chartBar = "chart-bar"
    case checkCircle = "check-circle"
    case checkSquareFill = "check-square-fill"
    case compass
    case crown
    case crownFill = "crown-fill"
    case crownSimple = "crown-simple"
    case crownSimpleFill = "crown-simple-fill"
    case detective
    case fileText = "file-text"
    case images
    case link
    case listMagnifyingGlass = "list-magnifying-glass"
    case medal
    case qrCode = "qr-code"
    case scales
    case sealCheck = "seal-check"
    case sealWarning = "seal-warning"
    case shieldCheck = "shield-check"
    case siren
    case star
    case square
    case thumbsDown = "thumbs-down"
    case thumbsUp = "thumbs-up"
    case trophy
    case userCircle = "user-circle"
    case userCircleFill = "user-circle-fill"
    case warningCircle = "warning-circle"
    case wine
    case wineFill = "wine-fill"

    var assetName: String {
        "phosphor/\(rawValue)"
    }
}

extension Image {
    init(phosphor icon: PhosphorIcon) {
        self.init(icon.assetName)
    }
}
