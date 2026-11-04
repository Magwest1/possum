import Foundation
import Security

public enum CodeSigning {
    /// Team identifier of the running process, or `nil` for ad-hoc / unsigned builds.
    public static func currentTeamID() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }

    /// Code signing requirement for the XPC peer with the given identifier.
    ///
    /// Release builds pin the peer to the same Apple-issued team certificate as
    /// the current process. Local ad-hoc builds have no team, so they fall back
    /// to matching the identifier only.
    public static func requirement(forPeer identifier: String, teamID: String? = currentTeamID()) -> String {
        guard let teamID, !teamID.isEmpty else {
            return "identifier \"\(identifier)\""
        }
        return "identifier \"\(identifier)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""
    }
}
