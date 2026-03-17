import Foundation

@MainActor
public enum InspectionLiveMonitorCoordinator {
    public typealias ToggleHandler = @MainActor (_ isEnabled: Bool) async throws -> Void

    private static var toggleHandler: ToggleHandler?

    public static func configure(toggleHandler: ToggleHandler?) {
        self.toggleHandler = toggleHandler
    }

    static func currentToggleHandler() -> ToggleHandler? {
        toggleHandler
    }
}
