import SwiftUI
import UIKit


enum AppPreferenceKeys {

    static let appearanceMode =
        "preferences.appearanceMode.v1"

    static let hapticsEnabled =
        "preferences.hapticsEnabled.v1"
}


enum AppAppearanceMode:
    String,
    CaseIterable,
    Identifiable {

    case system =
        "跟随系统"

    case light =
        "浅色"

    case dark =
        "深色"


    var id:
        String {

        rawValue
    }


    var colorScheme:
        ColorScheme? {

        switch self {

        case .system:
            return nil

        case .light:
            return .light

        case .dark:
            return .dark
        }
    }


    var icon:
        String {

        switch self {

        case .system:
            return "circle.lefthalf.filled"

        case .light:
            return "sun.max.fill"

        case .dark:
            return "moon.fill"
        }
    }
}


enum HapticFeedback {

    private static var isEnabled:
        Bool {

        if UserDefaults.standard
            .object(
                forKey:
                    AppPreferenceKeys
                        .hapticsEnabled
            ) ==
            nil {

            return true
        }

        return UserDefaults.standard
            .bool(
                forKey:
                    AppPreferenceKeys
                        .hapticsEnabled
            )
    }


    static func selection() {

        guard isEnabled
        else {
            return
        }

        UISelectionFeedbackGenerator()
            .selectionChanged()
    }


    static func success() {

        guard isEnabled
        else {
            return
        }

        UINotificationFeedbackGenerator()
            .notificationOccurred(
                .success
            )
    }


    static func error() {

        guard isEnabled
        else {
            return
        }

        UINotificationFeedbackGenerator()
            .notificationOccurred(
                .error
            )
    }
}
