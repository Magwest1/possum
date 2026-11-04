import Testing
@testable import PossumCore

struct PMSetTests {
    private let header = "System-wide power settings:\nCurrently in use:\n standby              1\n sleep                1\n"

    @Test func parsesEnabledFlag() {
        let output = "System-wide power settings:\n SleepDisabled\t\t1\nCurrently in use:\n sleep 1\n"
        #expect(PMSet.parseSleepDisabled(output) == true)
    }

    @Test func parsesExplicitZero() {
        let output = "System-wide power settings:\n SleepDisabled\t\t0\nCurrently in use:\n"
        #expect(PMSet.parseSleepDisabled(output) == false)
    }

    @Test func missingLineMeansSleepAllowed() {
        #expect(PMSet.parseSleepDisabled(header) == false)
    }

    @Test func garbageIsUnknown() {
        #expect(PMSet.parseSleepDisabled("") == nil)
        #expect(PMSet.parseSleepDisabled("pmset: command not found") == nil)
        #expect(PMSet.parseSleepDisabled("System-wide power settings:\n SleepDisabled\t\tmaybe\n") == nil)
    }

    @Test func ignoresSimilarlyNamedKeys() {
        let output = header + " SleepDisabledFoo 1\n"
        #expect(PMSet.parseSleepDisabled(output) == false)
    }

    @Test func argumentsAreFixed() {
        #expect(PMSet.arguments(sleepDisabled: true) == ["disablesleep", "1"])
        #expect(PMSet.arguments(sleepDisabled: false) == ["disablesleep", "0"])
    }
}

struct CodeSigningTests {
    @Test func pinsTeamWhenSigned() {
        let req = CodeSigning.requirement(forPeer: "a.b.c", teamID: "ABCDE12345")
        #expect(req == "identifier \"a.b.c\" and anchor apple generic and certificate leaf[subject.OU] = \"ABCDE12345\"")
    }

    @Test func fallsBackToIdentifierForAdHoc() {
        #expect(CodeSigning.requirement(forPeer: "a.b.c", teamID: nil) == "identifier \"a.b.c\"")
        #expect(CodeSigning.requirement(forPeer: "a.b.c", teamID: "") == "identifier \"a.b.c\"")
    }
}
