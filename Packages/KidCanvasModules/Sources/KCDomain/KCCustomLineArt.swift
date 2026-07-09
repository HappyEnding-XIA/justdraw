//
//  KCCustomLineArt.swift
//  KCDomain
//
//  Created by 小大 on 2026/07/09.
//

import Foundation
import KCCommon

/// “我的线稿”单条元数据（T099）。位图线稿（不做矢量化），独立于历史作品：
/// 删除一条我的线稿只删除线稿库条目本身，不影响基于该线稿保存过的历史作品。
///
/// 自动命名走稳定可读的 `sequenceNumber`（"我的线稿 N" 的 N），由 App 层本地化格式化，
/// 避免在 Swift 字符串字面量里写中文，也避免儿童无法理解的时间戳命名。
public struct KCCustomLineArt: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var sequenceNumber: Int
    public var lineArtFileName: String
    public var thumbnailFileName: String
    public var createdAt: Date
    public var sourceKind: KCCustomLineArtSourceKind
    public var sourceSessionId: String?

    public init(
        id: String,
        sequenceNumber: Int,
        lineArtFileName: String,
        thumbnailFileName: String,
        createdAt: Date = Date(),
        sourceKind: KCCustomLineArtSourceKind,
        sourceSessionId: String? = nil
    ) {
        self.id = id
        self.sequenceNumber = sequenceNumber
        self.lineArtFileName = lineArtFileName
        self.thumbnailFileName = thumbnailFileName
        self.createdAt = createdAt
        self.sourceKind = sourceKind
        self.sourceSessionId = sourceSessionId
    }
}

/// 我的线稿来源类型。T099 仅 `canvasSave`（当前画布保存为线稿）；
/// `photoExtraction` 为 T101（照片生成线稿）预留。
public enum KCCustomLineArtSourceKind: String, Codable, Sendable {
    case canvasSave
    case photoExtraction
}

/// “我的线稿”本地读写契约（UIKit-free）。图像载荷以 `Data` 交换
/// （线稿为 PNG，缩略图为 JPEG）。实现位于 `KCSessionPersistence`，
/// 磁盘布局独立于历史会话：`Documents/KidCanvasCustomLineArt/`、
/// `custom-line-arts.json`、`<id>.png`、`<id>-thumb.jpg`。
public protocol KCCustomLineArtRepository: Sendable {
    /// 加载全部我的线稿，最新创建的排在最前。
    func loadAll() throws -> [KCCustomLineArt]

    /// 保存一条位图线稿及其缩略图，自动分配 `sequenceNumber`。
    /// 返回已存储的条目；若图像无效或已达数量上限则返回 `nil`。
    func save(
        lineArtPNG: Data,
        thumbnailJPEG: Data,
        sourceKind: KCCustomLineArtSourceKind,
        sourceSessionId: String?
    ) throws -> KCCustomLineArt?

    /// 加载某条线稿的全分辨率 PNG 数据。
    func lineArtData(for item: KCCustomLineArt) -> Data?

    /// 加载某条线稿的缩略图 JPEG 数据。
    func thumbnailData(for item: KCCustomLineArt) -> Data?

    /// 删除一条我的线稿及其关联文件（不影响历史作品）。
    func delete(_ item: KCCustomLineArt) throws

    /// 当前我的线稿数量。
    func count() throws -> Int
}
