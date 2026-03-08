import Foundation

private final class InspectTestBundleToken {}

func inspectTestFixtureURL(named name: String, extension fileExtension: String) -> URL? {
#if SWIFT_PACKAGE
    Bundle.module.url(forResource: name, withExtension: fileExtension)
#else
    Bundle(for: InspectTestBundleToken.self).url(forResource: name, withExtension: fileExtension)
#endif
}
