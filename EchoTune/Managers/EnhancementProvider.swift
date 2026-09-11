import Foundation

/// Common seam for hosted, remote, and local enhancement implementations.
/// The public AIEnhancementEngine entry point remains the routing surface used
/// by the UI; providers never receive shell-interpolated user input.
protocol EnhancementProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var isAvailable: Bool { get }
    func polish(_ text: String, prompt: String) async throws -> String
}
