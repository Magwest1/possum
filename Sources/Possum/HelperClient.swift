import Foundation
import PossumCore
import ServiceManagement

enum HelperError: LocalizedError {
    case requiresApproval
    case registrationFailed(String)
    case connection(String)
    case helper(String)

    var errorDescription: String? {
        switch self {
        case .requiresApproval:
            return "Allow the Possum helper in System Settings › General › Login Items & Extensions, then try again."
        case .registrationFailed(let detail):
            return "Could not install the Possum helper: \(detail)"
        case .connection(let detail):
            return "Could not reach the Possum helper: \(detail)"
        case .helper(let detail):
            return detail
        }
    }
}

/// Registers the privileged helper with launchd and talks to it over XPC.
final class HelperClient {
    private let service = SMAppService.daemon(plistName: Possum.helperPlistName)

    var status: SMAppService.Status { service.status }

    /// Registers the helper if needed. Throws `.requiresApproval` until the user allows it.
    func ensureRegistered() throws {
        switch service.status {
        case .enabled:
            return
        case .requiresApproval:
            throw HelperError.requiresApproval
        case .notRegistered, .notFound:
            do {
                try service.register()
            } catch {
                if service.status == .requiresApproval { throw HelperError.requiresApproval }
                throw HelperError.registrationFailed(error.localizedDescription)
            }
            if service.status == .requiresApproval { throw HelperError.requiresApproval }
        @unknown default:
            throw HelperError.registrationFailed("unknown service status")
        }
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Asks the helper to set `SleepDisabled`. Completion runs on the main queue.
    func setSleepDisabled(_ disabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        // The XPC error handler and the reply are mutually exclusive in theory;
        // guard anyway so the completion can never run twice.
        let lock = NSLock()
        var finished = false
        let finish: (Result<Void, Error>) -> Void = { result in
            lock.lock()
            defer { lock.unlock() }
            guard !finished else { return }
            finished = true
            DispatchQueue.main.async { completion(result) }
        }
        do {
            try ensureRegistered()
        } catch {
            finish(.failure(error))
            return
        }

        let connection = NSXPCConnection(machServiceName: Possum.helperLabel, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: PossumHelperProtocol.self)
        connection.setCodeSigningRequirement(CodeSigning.requirement(forPeer: Possum.helperLabel))
        connection.resume()

        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            connection.invalidate()
            finish(.failure(HelperError.connection(error.localizedDescription)))
        } as? PossumHelperProtocol

        guard let proxy else {
            connection.invalidate()
            finish(.failure(HelperError.connection("unexpected proxy type")))
            return
        }

        proxy.setSleepDisabled(disabled) { success, message in
            connection.invalidate()
            finish(success ? .success(()) : .failure(HelperError.helper(message ?? "Unknown helper error")))
        }
    }
}
