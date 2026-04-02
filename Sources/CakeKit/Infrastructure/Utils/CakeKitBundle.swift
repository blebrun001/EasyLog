import Foundation

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
