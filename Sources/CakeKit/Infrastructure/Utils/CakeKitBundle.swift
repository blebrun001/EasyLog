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

    private final class BundleFinder {}
}
