public enum InspectionSettingsStrings {
    public static let navigationTitle = "Settings"

    public enum Shared {
        public static let connection = "Connection"
        public static let configured = "Configured"
        public static let diagnostics = "Diagnostics"
        public static let events = "Events"
        public static let tunnelLog = "Tunnel Log"
        public static let verbose = "Verbose"
        public static let about = "About"
        public static let version = "Version"
        public static let aboutInspect = "About Inspect"
        public static let rateOnAppStore = "Rate on App Store"
        public static let verboseFooter = "Verbose logging applies on the next Live Monitor start."
    }

    public enum IOS {
        public static let liveMonitorSection = "Live Monitor Tunnel"
        public static let invalidMonitorMessage = "Use the Live Monitor switch in the Monitor tab to install and control the profile."
        public static let diagnosticsFooter = "Use Events and Tunnel Log for troubleshooting. \(Shared.verboseFooter)"
    }

    public enum Mac {
        public static let liveMonitorSection = "Live Monitor"
        public static let provider = "Provider"
        public static let liveMonitorFooter = "Use System Settings to manage the Packet Tunnel profile on this Mac."
    }
}
