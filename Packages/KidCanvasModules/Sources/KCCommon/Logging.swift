//
//  Logging.swift
//  KCCommon
//
//  Created by 小大 on 2026/06/25.
//

import Foundation

/// A minimal logging seam so modules can emit diagnostics without depending on
/// `os.Logger` availability or a concrete logging framework.
///
/// The app shell assigns a concrete sink at startup. By default logs are dropped,
/// which keeps the package testable and framework-free.
public protocol KCLogging: Sendable {
    func log(_ level: KCLogLevel, _ message: @autoclosure () -> String)
}

public enum KCLogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

/// Global logging sink. Swap this out from the app shell; modules call `KCLog`.
public enum KCLog {
    nonisolated(unsafe) public static var sink: any KCLogging = KCNullLogger()

    public static func debug(_ message: @autoclosure () -> String) {
        sink.log(.debug, message())
    }

    public static func info(_ message: @autoclosure () -> String) {
        sink.log(.info, message())
    }

    public static func warning(_ message: @autoclosure () -> String) {
        sink.log(.warning, message())
    }

    public static func error(_ message: @autoclosure () -> String) {
        sink.log(.error, message())
    }
}

/// Default no-op logger.
public struct KCNullLogger: KCLogging {
    public init() {}
    public func log(_ level: KCLogLevel, _ message: @autoclosure () -> String) {}
}

/// A logger that buffers messages in memory, useful for tests and debugging.
public final class KCBufferedLogger: KCLogging, @unchecked Sendable {
    public struct Entry: Equatable, Sendable {
        public let level: KCLogLevel
        public let message: String
    }

    private let lock = NSLock()
    private var entries: [Entry] = []

    public init() {}

    public func log(_ level: KCLogLevel, _ message: @autoclosure () -> String) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(Entry(level: level, message: message()))
    }

    public func snapshot() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }
}
