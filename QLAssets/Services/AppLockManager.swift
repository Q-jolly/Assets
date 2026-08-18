import Foundation
import LocalAuthentication


@MainActor
final class AppLockManager:
    ObservableObject {

    static let appLockEnabledKey =
        "security.appLockEnabled"

    static let hideInSwitcherKey =
        "security.hideInAppSwitcher"


    @Published
    private(set)
    var isLocked =
        false

    @Published
    private(set)
    var isAuthenticating =
        false

    @Published
    var lastErrorMessage:
        String?


    var isAppLockEnabled:
        Bool {

        get {

            UserDefaults.standard
                .bool(
                    forKey:
                        Self
                            .appLockEnabledKey
                )
        }

        set {

            UserDefaults.standard
                .set(
                    newValue,
                    forKey:
                        Self
                            .appLockEnabledKey
                )

            if !newValue {

                isLocked =
                    false
            }
        }
    }


    var hideInAppSwitcher:
        Bool {

        get {

            if UserDefaults.standard
                .object(
                    forKey:
                        Self
                            .hideInSwitcherKey
                ) ==
                nil {

                return true
            }

            return UserDefaults.standard
                .bool(
                    forKey:
                        Self
                            .hideInSwitcherKey
                )
        }

        set {

            UserDefaults.standard
                .set(
                    newValue,
                    forKey:
                        Self
                            .hideInSwitcherKey
                )
        }
    }


    var authenticationTitle:
        String {

        let context =
            LAContext()

        var error:
            NSError?

        _ =
            context
                .canEvaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    error:
                        &error
                )


        switch context.biometryType {

        case .faceID:

            return
                "Face ID"

        case .touchID:

            return
                "Touch ID"

        case .opticID:

            return
                "Optic ID"

        case .none:

            return
                "设备验证"

        @unknown default:

            return
                "设备验证"
        }
    }


    func lockIfNeeded() {

        guard isAppLockEnabled
        else {

            isLocked =
                false

            return
        }

        isLocked =
            true
    }


    func lockNow() {

        guard isAppLockEnabled
        else {
            return
        }

        isLocked =
            true
    }


    func authenticateForEnabling()
        async -> Bool {

        await authenticate(
            reason:
                "验证身份后开启 QL Assets 应用锁"
        )
    }


    func unlock()
        async -> Bool {

        guard isAppLockEnabled
        else {

            isLocked =
                false

            return true
        }


        let success =
            await authenticate(
                reason:
                    "解锁 QL Assets，查看你的资产信息"
            )


        if success {

            isLocked =
                false
        }

        return success
    }


    private func authenticate(
        reason:
            String
    ) async -> Bool {

        guard !isAuthenticating
        else {

            return false
        }


        isAuthenticating =
            true

        lastErrorMessage =
            nil


        defer {

            isAuthenticating =
                false
        }


        let context =
            LAContext()

        context.localizedCancelTitle =
            "取消"

        context.localizedFallbackTitle =
            "使用设备密码"


        var error:
            NSError?


        guard
            context.canEvaluatePolicy(
                .deviceOwnerAuthentication,
                error:
                    &error
            )
        else {

            lastErrorMessage =
                error?
                    .localizedDescription
                ?? "当前设备无法进行身份验证"

            return false
        }


        do {

            let success =
                try await context
                    .evaluatePolicy(
                        .deviceOwnerAuthentication,
                        localizedReason:
                            reason
                    )

            if !success {

                lastErrorMessage =
                    "身份验证未通过"
            }

            return success

        } catch {

            let nsError =
                error as NSError


            if nsError.code !=
                LAError
                    .userCancel
                    .rawValue &&
               nsError.code !=
                LAError
                    .systemCancel
                    .rawValue {

                lastErrorMessage =
                    error
                        .localizedDescription
            }

            return false
        }
    }
}
