import SwiftUI
import SwiftData


struct AppLockContainerView:
    View {

    @Environment(
        \.scenePhase
    )
    private var scenePhase

    @EnvironmentObject
    private var appLock:
        AppLockManager

    @Environment(
        \.modelContext
    )
    private var modelContext

    @State
    private var attemptedInitialUnlock =
        false


    var body:
        some View {

        ZStack {

            ContentView()
                .allowsHitTesting(
                    !appLock.isLocked
                )


            if appLock.isLocked {

                AppLockedView()
                    .transition(
                        .opacity
                            .combined(
                                with:
                                    .scale(
                                        scale:
                                            0.985
                                    )
                            )
                    )
                    .zIndex(20)
            }


            if scenePhase ==
                .background &&
               appLock
                .hideInAppSwitcher {

                PrivacySnapshotCover()
                    .zIndex(30)
            }
        }
        .animation(
            .easeOut(
                duration:
                    0.10
            ),
            value:
                appLock
                    .isLocked
        )
        .onAppear {

            CategoryDataMigration
                .run(
                    context:
                        modelContext
                )

            appLock
                .prepareForLaunch()

            guard
                appLock
                    .isLocked,
                !attemptedInitialUnlock
            else {
                return
            }

            attemptedInitialUnlock =
                true

            Task {

                _ =
                    await appLock
                        .unlock()
            }
        }
        .onChange(
            of:
                scenePhase
        ) { _, newPhase in

            switch newPhase {

            case .active:

                let needsUnlock =
                    appLock
                        .shouldUnlockAfterBecomingActive()

                if needsUnlock {

                    Task {

                        _ =
                            await appLock
                                .unlock()
                    }
                }

            case .background:

                appLock
                    .didEnterBackground()

            case .inactive:

                // Face ID、控制中心、通知中心等都会短暂进入 inactive。
                // 这里不锁定，也不启动 5 分钟计时。
                break

            @unknown default:

                break
            }
        }
    }
}


// MARK: - 锁屏页

private struct AppLockedView:
    View {

    @EnvironmentObject
    private var appLock:
        AppLockManager


    var body:
        some View {

        ZStack {

            Rectangle()
                .fill(
                    .ultraThinMaterial
                )
                .ignoresSafeArea()


            VStack(
                spacing: 18
            ) {

                Image(
                    systemName:
                        "lock.shield.fill"
                )
                .font(
                    .system(
                        size: 52,
                        weight:
                            .semibold
                    )
                )


                VStack(
                    spacing: 6
                ) {

                    Text(
                        "QL Assets 已锁定"
                    )
                    .font(
                        .title2.bold()
                    )

                    Text(
                        "验证身份后查看资产、账单和银行卡"
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .multilineTextAlignment(
                        .center
                    )
                }


                Button {

                    Task {

                        _ =
                            await appLock
                                .unlock()
                    }

                } label: {

                    HStack {

                        if appLock
                            .isAuthenticating {

                            ProgressView()
                                .tint(
                                    .white
                                )
                        } else {

                            Image(
                                systemName:
                                    biometricIcon
                            )
                        }


                        Text(
                            appLock
                                .isAuthenticating
                            ? "正在验证..."
                            : "使用 \(appLock.authenticationTitle) 解锁"
                        )
                    }
                    .fontWeight(
                        .semibold
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding(
                        .vertical,
                        13
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    appLock
                        .isAuthenticating
                )


                if let error =
                    appLock
                        .lastErrorMessage {

                    Text(
                        error
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .multilineTextAlignment(
                        .center
                    )
                }
            }
            .padding(28)
            .frame(
                maxWidth:
                    430
            )
        }
    }


    private var biometricIcon:
        String {

        switch appLock
            .authenticationTitle {

        case "Face ID":

            return
                "faceid"

        case "Touch ID":

            return
                "touchid"

        default:

            return
                "lock.open.fill"
        }
    }
}


// MARK: - App 切换器隐私遮罩

private struct PrivacySnapshotCover:
    View {

    var body:
        some View {

        ZStack {

            Color(
                .systemBackground
            )
            .ignoresSafeArea()


            VStack(
                spacing: 12
            ) {

                Image(
                    systemName:
                        "eye.slash.fill"
                )
                .font(
                    .system(
                        size: 42
                    )
                )

                Text(
                    "QL Assets"
                )
                .font(
                    .title3.bold()
                )

                Text(
                    "资产信息已隐藏"
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }
}
