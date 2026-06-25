import Foundation

/// Shared error type for KidCanvas modules.
///
/// Modules surface failures through a single, descriptive enum so that the app
/// shell and feature layers can switch over known cases without importing every
/// module's bespoke error type.
public enum KCError: Error, Equatable, Sendable {
    /// A required file or directory could not be located.
    case missingResource(String)
    /// An I/O operation (read/write/move) failed.
    case ioFailure(String)
    /// On-disk data could not be decoded into the expected type.
    case decodingFailed(String)
    /// Input failed a precondition (invalid image, empty identifier, etc.).
    case invalidInput(String)
    /// A legacy format was detected but could not be migrated by this module.
    case legacyMigrationDeferred(String)
}
