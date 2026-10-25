import Foundation
import SwiftData
import os

/// Builds the app's SwiftData stack.
///
/// v1 is **local-only**: all data — the child's profile, targets, and practice history —
/// stays on device, which is the privacy contract shown in the UI ("Data Not Collected").
/// CloudKit sync across the user's own devices is a deliberate future step; the single
/// `ModelConfiguration` below is the seam where a `.private(...)` database would slot in.
@Observable
final class PersistenceController {
    let container: ModelContainer
    /// True for the throwaway in-memory store used by tests and `-localStore` runs.
    let isInMemory: Bool

    static let log = Logger(subsystem: "com.adrianmcgee.tadpoletalk", category: "persistence")

    init(inMemory: Bool = false) {
        Self.ensureApplicationSupportExists()

        let schema = Schema(versionedSchema: TadpoleTalkSchemaV1.self)
        // Unit/UI tests pass "-localStore" (or run under XCTest) to force an isolated,
        // throwaway store so a test run never touches real on-device data.
        let env = ProcessInfo.processInfo.environment
        let runningTests = env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil
        let memory = inMemory || runningTests
            || ProcessInfo.processInfo.arguments.contains("-localStore")
        self.isInMemory = memory

        let config = ModelConfiguration(
            "TadpoleTalk",
            schema: schema,
            isStoredInMemoryOnly: memory,
            cloudKitDatabase: .none
        )
        do {
            self.container = try ModelContainer(
                for: schema, migrationPlan: TadpoleTalkMigrationPlan.self, configurations: config
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// SwiftData's default store lives in Application Support, which doesn't exist on a
    /// fresh install — the first store-create then fails with NSCocoaError 512. Create it
    /// up front so first launch is reliable.
    private static func ensureApplicationSupportExists() {
        if let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
    }
}
