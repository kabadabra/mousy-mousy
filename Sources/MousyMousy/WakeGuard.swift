import Foundation
import IOKit.pwr_mgt

/// Belt and braces: synthetic events keep SOFTWARE seeing activity, IOPM keeps
/// the MACHINE awake. Standing display-sleep assertion + periodic user-activity
/// declarations (the Jiggler/KeepingYouAwake pattern).
@MainActor
final class WakeGuard {
    private var sleepAssertion: IOPMAssertionID = 0
    private var activityID: IOPMAssertionID = 0
    private var timer: Timer?

    func start() {
        stop()
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    "Mousy Mousy is keeping the display awake" as CFString,
                                    &sleepAssertion)
        declareActivity()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.declareActivity() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if sleepAssertion != 0 {
            IOPMAssertionRelease(sleepAssertion)
            sleepAssertion = 0
        }
    }

    private func declareActivity() {
        // Reusing activityID replaces the previous declaration.
        IOPMAssertionDeclareUserActivity("Mousy Mousy activity" as CFString,
                                         kIOPMUserActiveLocal, &activityID)
    }
}
