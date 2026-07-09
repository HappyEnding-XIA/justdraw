//
//  KCContentLibraryFeature.swift
//  KidCanvas
//
//  Created by 小大 on 2026/07/09.
//

import UIKit
import KCDomain

/// App 层内容库 Feature（T098）：统一承载官方线稿、我的线稿、历史作品三个分区
/// 的按需浏览面板的状态与决策边界。
///
/// 本类型持有“面板可见性”和“当前分区”两类轻量 UI 状态，并把分区能力、空态、删除
/// 可用性等纯逻辑委托给 KCDomain `KCContentLibraryPartition` /
/// `KCContentLibrarySectionState`。视图构建（分段控件、网格、缩略图、历史面板容器）、
/// 数据装配（官方线稿来自 `KCLineArtFeature`、历史来自控制器内存 `sessions`）与
/// 打开/删除事件协调仍留 `KCMainViewController`。
///
/// 边界（与 `KCHistoryFeature` 一致）：不触碰 `KCSessionService`/`KCSessionStore`
/// 磁盘格式，不生成线稿，不持有系统 picker；我的线稿与导入结果分区本轮为预留空态，
/// 真实数据源在 T099/T100/T101 接入。
final class KCContentLibraryFeature {

    /// 内容库浮层是否可见。
    private(set) var isPanelVisible: Bool = false

    /// 当前选中的分区（默认官方线稿）。
    private(set) var currentPartition: KCContentLibraryPartition = .officialLineArt

    /// 分段控件的分区顺序。
    func partitions() -> [KCContentLibraryPartition] {
        KCContentLibraryPartition.defaultOrder
    }

    /// 默认分区。
    var defaultPartition: KCContentLibraryPartition {
        .officialLineArt
    }

    /// 推导某分区在给定条目数下的展示状态。
    func sectionState(for partition: KCContentLibraryPartition, itemCount: Int) -> KCContentLibrarySectionState {
        KCContentLibrarySectionState(partition: partition, itemCount: itemCount)
    }

    /// 某分区当前是否允许删除任一条目（分区允许删除且非空）。
    func canDelete(in partition: KCContentLibraryPartition, itemCount: Int) -> Bool {
        sectionState(for: partition, itemCount: itemCount).canDeleteAny
    }

    /// 某分区当前是否为空态。
    func isEmpty(partition: KCContentLibraryPartition, itemCount: Int) -> Bool {
        sectionState(for: partition, itemCount: itemCount).isEmpty
    }

    /// 显示面板。返回是否发生状态变化（调用方可据此决定是否刷新 UI）。
    @discardableResult
    func show() -> Bool {
        guard !isPanelVisible else { return false }
        isPanelVisible = true
        return true
    }

    /// 隐藏面板。
    @discardableResult
    func hide() -> Bool {
        guard isPanelVisible else { return false }
        isPanelVisible = false
        return true
    }

    /// 切换面板可见性。
    @discardableResult
    func toggleVisibility() -> Bool {
        isPanelVisible ? hide() : show()
    }

    /// 切换分区。返回是否发生状态变化。
    @discardableResult
    func selectPartition(_ partition: KCContentLibraryPartition) -> Bool {
        guard currentPartition != partition else { return false }
        currentPartition = partition
        return true
    }
}
