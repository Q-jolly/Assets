import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 60))

            Text("QL Assets")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("iOS 环境配置成功")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
