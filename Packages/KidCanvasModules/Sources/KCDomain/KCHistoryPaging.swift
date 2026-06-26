//
//  KCHistoryPaging.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/26.
//

import Foundation

/// Pure, UIKit-free model for the saved-artwork history pager — the first
/// extracted boundary of the history Feature (`KCHistoryFeature`).
///
/// The Objective-C `KDMainViewController` previously inlined all of this paging
/// math (max page index, page clamping, thumbnail→session index mapping). It is
/// lifted here verbatim so it is unit-testable and so the controller communicates
/// with the history Feature through this typed interface instead of scattering
/// the arithmetic. UIKit rendering (the thumbnail buttons themselves) still lives
/// in the controller; this type owns only the navigation model.
public struct KCHistoryPaging: Equatable, Sendable {

    /// Number of saved sessions being paged across.
    public let sessionCount: Int

    /// Number of thumbnail slots per page (the controller's `historyPageSize`,
    /// derived from the number of thumbnail buttons).
    public let pageSize: Int

    /// Currently visible page index.
    public var pageIndex: Int

    public init(sessionCount: Int, pageSize: Int, pageIndex: Int = 0) {
        self.sessionCount = max(0, sessionCount)
        self.pageSize = pageSize
        self.pageIndex = pageIndex
    }

    /// Effective page size, never below 1 — matches the prototype's
    /// `MAX(1, historyPageSize)` guard used everywhere it divides.
    public var effectivePageSize: Int {
        max(1, pageSize)
    }

    /// Highest valid page index. Returns `0` when there are no sessions,
    /// matching the prototype's `maxHistoryPageIndex`.
    public var maxPageIndex: Int {
        guard sessionCount > 0 else { return 0 }
        return (sessionCount - 1) / effectivePageSize
    }

    /// `pageIndex` clamped to `[0, maxPageIndex]`, matching the prototype's
    /// `MIN(MAX(0, pageIndex), maxPageIndex)` in `refreshHistoryUI`.
    public var clampedPageIndex: Int {
        min(max(0, pageIndex), maxPageIndex)
    }

    /// Whether the user can page forward (next).
    public var canAdvance: Bool {
        pageIndex < maxPageIndex
    }

    /// Whether the user can page back (previous).
    public var canRetreat: Bool {
        pageIndex > 0
    }

    /// Maps a thumbnail slot `thumbIndex` within the current page to its absolute
    /// session index, matching the prototype's `sessionIndexForHistoryThumbIndex:`
    /// (`pageIndex * pageSize + thumbIndex`).
    public func sessionIndex(forThumb thumbIndex: Int) -> Int {
        pageIndex * effectivePageSize + thumbIndex
    }
}
