import SwiftUI

enum PhosphorIcon: String, CaseIterable {
    case arrowsSplit = "arrows-split"
    case binoculars
    case compass
    case crown
    case crownSimple = "crown-simple"
    case detective
    case listMagnifyingGlass = "list-magnifying-glass"
    case medal
    case scales
    case sealWarning = "seal-warning"
    case shieldCheck = "shield-check"
    case siren
    case star
    case trophy
    case warningCircle = "warning-circle"

    var assetName: String {
        "phosphor/\(rawValue)"
    }
}

extension Image {
    init(phosphor icon: PhosphorIcon) {
        self.init(icon.assetName)
    }
}
