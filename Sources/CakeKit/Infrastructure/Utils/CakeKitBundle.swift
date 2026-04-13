import Foundation

/// Resolves the correct resource bundle in SPM and Xcode contexts.
public enum CakeKitBundle {
    public static var resources: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle(for: BundleFinder.self)
        #endif
    }

    public static var resourceProfile: USGSResourceProfile {
        if let raw = ProcessInfo.processInfo.environment["CAKE_RESOURCE_PROFILE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           let profile = USGSResourceProfile(rawValue: raw) {
            return profile
        }

        // Default to release assets unless explicitly overridden by CAKE_RESOURCE_PROFILE.
        // This keeps rendering behavior consistent between debug and release builds.
        return .release
    }

    private final class BundleFinder {}
}
