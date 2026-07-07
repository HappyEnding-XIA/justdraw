//
//  KCRepositories.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/25.
//

import Foundation
import KCCommon

/// 已保存作品会话的读写契约。
///
/// 图像载荷以 `Data` 交换（作品为 PNG，缩略图为 JPEG），使该协议保持
/// 不依赖 `UIKit`。实现位于 `KCSessionPersistence`，并保持与 Objective-C
/// `KDSessionStore` 相同的磁盘布局（`Documents/KidCanvasSessions/`、
/// `<uuid>.png`、`<uuid>-thumb.jpg`、`draft.png`）。
public protocol KCSessionRepository: Sendable {
    /// 加载全部会话，最新的排在最前。
    func loadSessions() throws -> [KCArtworkSession]

    /// 持久化作品及其缩略图，创建或更新会话。
    /// 返回已存储的会话；若图像无效则返回 `nil`。
    func saveArtwork(
        pngData: Data,
        thumbnailJPEGData: Data,
        existing: KCArtworkSession?
    ) throws -> KCArtworkSession?

    /// 加载会话的全分辨率作品图像数据。
    func artworkData(for session: KCArtworkSession) -> Data?

    /// 加载会话的缩略图图像数据。
    func thumbnailData(for session: KCArtworkSession) -> Data?

    /// 删除会话及其关联文件。
    func delete(_ session: KCArtworkSession) throws

    /// 当至少保存了一个会话时为 `true`。
    func hasSavedSessions() throws -> Bool

    /// 当自动保存草稿文件存在时为 `true`；不得为了判断存在性读取或解码草稿图片。
    func hasDraft() -> Bool

    /// 用给定的 PNG 数据覆盖自动保存的草稿。
    func saveDraft(pngData: Data) throws -> Bool

    /// 加载自动保存草稿的 PNG 数据（若存在）。
    func loadDraft() -> Data?

    /// 删除自动保存的草稿。
    func clearDraft()
}

/// 从系统选择器中选取的照片。
public struct KCImportedPhoto: Sendable {
    public let imageData: Data
    public init(imageData: Data) { self.imageData = imageData }
}

/// 系统相册的导入/导出契约。
///
/// 定义在领域层（不依赖 UIKit），以便各 Feature 依赖该抽象；具体适配器位于
/// App/相册模块中。
public protocol KCPhotoLibraryServicing: Sendable {
    /// 将图像数据（PNG/JPEG）导出到已保存相册。
    @discardableResult
    func export(imageData: Data) async -> Bool

    /// 弹出照片选择器，并返回所选照片（若有）。
    func importPhoto() async -> KCImportedPhoto?
}
