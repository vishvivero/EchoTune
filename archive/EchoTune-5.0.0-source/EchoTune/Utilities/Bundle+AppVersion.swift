import Foundation

extension Bundle {
    var appVersionString: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var appBuildString: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    var appVersionWithBuild: String {
        "\(appVersionString) (Build \(appBuildString))"
    }
}
