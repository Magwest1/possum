import Foundation
import PossumCore
import os

// Privileged helper. Registered by the app through SMAppService and started on
// demand by launchd when the app connects to its Mach service. It exits after a
// short idle period so an updated app bundle always runs the matching helper.

private let log = Logger(subsystem: Possum.helperLabel, category: "helper")
private let idleTimeout: TimeInterval = 60

final class Helper: NSObject, PossumHelperProtocol {
    private let queue = DispatchQueue(label: "\(Possum.helperLabel).pmset")
    private let onActivity: () -> Void

    init(onActivity: @escaping () -> Void) {
        self.onActivity = onActivity
    }

    func setSleepDisabled(_ disabled: Bool, reply: @escaping (Bool, String?) -> Void) {
        onActivity()
        queue.async {
            let result = PMSet.run(PMSet.arguments(sleepDisabled: disabled))
            guard result.status == 0 else {
                log.error("pmset failed with status \(result.status): \(result.output, privacy: .public)")
                reply(false, "pmset exited with status \(result.status): \(result.output)")
                return
            }
            let actual = PMSet.readSleepDisabled()
            if actual == disabled {
                log.info("SleepDisabled set to \(disabled)")
                reply(true, nil)
            } else {
                reply(false, "pmset succeeded but SleepDisabled reads \(actual.map(String.init) ?? "unknown")")
            }
        }
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let requirement = CodeSigning.requirement(forPeer: Possum.appBundleID)
    private var idleTimer: DispatchSourceTimer?

    override init() {
        super.init()
        log.info("Accepting clients matching: \(self.requirement, privacy: .public)")
        resetIdleTimer()
    }

    func resetIdleTimer() {
        DispatchQueue.main.async {
            self.idleTimer?.cancel()
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + idleTimeout)
            timer.setEventHandler { exit(0) }
            timer.resume()
            self.idleTimer = timer
        }
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: PossumHelperProtocol.self)
        connection.exportedObject = Helper { [weak self] in self?.resetIdleTimer() }
        connection.resume()
        resetIdleTimer()
        return true
    }
}

let delegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: Possum.helperLabel)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
