import Foundation

public enum PMSet {
    /// Arguments for `pmset` that set the system-wide `SleepDisabled` flag.
    public static func arguments(sleepDisabled: Bool) -> [String] {
        ["disablesleep", sleepDisabled ? "1" : "0"]
    }

    /// Parses the output of `pmset -g` and returns the `SleepDisabled` value.
    ///
    /// `pmset` only prints the `SleepDisabled` line when the flag is set, so a
    /// well-formed report without that line means sleep is allowed. Returns
    /// `nil` when the output does not look like a `pmset -g` report at all.
    public static func parseSleepDisabled(_ output: String) -> Bool? {
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2, fields[0] == "SleepDisabled" else { continue }
            switch fields[1] {
            case "1": return true
            case "0": return false
            default: return nil
            }
        }
        let looksValid = output.contains("System-wide power settings") || output.contains("Currently in use")
        return looksValid ? false : nil
    }

    /// Runs `pmset` with the given arguments and returns its exit status and combined output.
    @discardableResult
    public static func run(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Possum.pmsetPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// Reads the current `SleepDisabled` value. Does not require root.
    public static func readSleepDisabled() -> Bool? {
        let result = run(["-g"])
        guard result.status == 0 else { return nil }
        return parseSleepDisabled(result.output)
    }
}
