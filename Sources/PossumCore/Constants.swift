import Foundation

public enum Possum {
    /// Bundle identifier of the menu bar app.
    public static let appBundleID = "io.github.magwest1.possum"
    /// launchd label and Mach service name of the privileged helper.
    public static let helperLabel = "io.github.magwest1.possum.helper"
    /// Name of the launchd plist embedded in `Contents/Library/LaunchDaemons`.
    public static let helperPlistName = "\(helperLabel).plist"
    /// The only binary the helper ever executes.
    public static let pmsetPath = "/usr/bin/pmset"
}

/// XPC interface exposed by the privileged helper.
///
/// Deliberately tiny: the helper accepts a single boolean and maps it to one of
/// two fixed `pmset` invocations. No arguments from the client reach the shell.
@objc public protocol PossumHelperProtocol {
    func setSleepDisabled(_ disabled: Bool, reply: @escaping (_ success: Bool, _ message: String?) -> Void)
}
