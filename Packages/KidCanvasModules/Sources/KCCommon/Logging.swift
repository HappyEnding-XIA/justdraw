//
//  Logging.swift
//  KCCommon
//
//  Created by 小大 on 2026/06/25.
//

import Foundation

/// 一个最小化的日志接口（seam），使各模块可以输出诊断信息，而无需依赖
/// `os.Logger` 的可用性或某个具体的日志框架。
///
/// app 外壳会在启动时指派具体的日志 sink。默认情况下日志会被丢弃，
/// 从而保持本包可测试且不依赖任何框架。
public protocol KCLogging: Sendable {
    func log(_ level: KCLogLevel, _ message: @autoclosure () -> String)
}

public enum KCLogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

/// 全局日志 sink。从 app 外壳处替换它；各模块调用 `KCLog`。
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

/// 默认的空操作（no-op）日志器。
public struct KCNullLogger: KCLogging {
    public init() {}
    public func log(_ level: KCLogLevel, _ message: @autoclosure () -> String) {}
}

/// 将日志消息缓冲在内存中的日志器，适用于测试和调试。
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
