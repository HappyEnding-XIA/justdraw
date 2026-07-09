//
//  KCContentLibrary.swift
//  KCDomain
//
//  Created by 小大 on 2026/07/09.
//

import Foundation

/// 内容库（Content Library）的 UIKit-free 纯逻辑模型——T098 的状态边界，T102 收口。
///
/// 内容库按需展开，统一承载官方线稿、我的线稿、历史作品三个主分区；导入结果为预留
/// 分区（T100/T101 接入），**不进入 `defaultOrder`**，不得打乱前三个主分区的固定顺序
/// （官方线稿 → 我的线稿 → 历史作品）。本类型只描述分区能力、分区展示状态与空态判定，
/// 不依赖 UIKit、不读取会话文件、不生成线稿、不持有系统 picker；真正的 UIKit 面板编排
/// 与数据装配由 App 层 `KCContentLibraryFeature` / `KCMainViewController` 完成。
public enum KCContentLibraryPartition: Int, Equatable, Sendable {

    /// 官方线稿：来自 `KCContentCatalog`，只读，不可删除。
    case officialLineArt = 0
    /// 我的线稿：T099 引入本地生命周期；可打开、可删除，独立于历史作品。
    case myLineArt
    /// 历史作品：来自 `KCSessionService`，可打开、可删除（语义不同于我的线稿）。
    case history
    /// 导入结果（预留）：T100/T101 接入；不在 `defaultOrder` 内，不作为可见主分区。
    case imports

    /// 所有分区都支持打开。
    public var allowsOpen: Bool { true }

    /// 官方线稿不可删除；我的线稿、历史作品、导入结果可删除。
    public var allowsDelete: Bool { self != .officialLineArt }

    /// 是否为可见主分区（出现在分段控件中）。导入结果为预留分区，暂不可见。
    public var isMainPartition: Bool { Self.defaultOrder.contains(self) }

    /// 分区稳定标识，供 App 层派生本地化 key（本层不直接持有文案）。
    public var localizationKey: String {
        switch self {
        case .officialLineArt: return "library.partition.official-line-art"
        case .myLineArt: return "library.partition.my-line-art"
        case .history: return "library.partition.history"
        case .imports: return "library.partition.imports"
        }
    }

    /// 分段控件的固定顺序（官方线稿 → 我的线稿 → 历史作品）。
    /// 导入结果为预留分区，不进入此顺序，避免打乱三个主分区（T102）。
    public static var defaultOrder: [KCContentLibraryPartition] {
        [.officialLineArt, .myLineArt, .history]
    }
}

/// 单个分区在当前数据下的展示状态：条目数、空态、是否允许删除任一条目。
public struct KCContentLibrarySectionState: Equatable, Sendable {

    public let partition: KCContentLibraryPartition
    public let itemCount: Int

    public init(partition: KCContentLibraryPartition, itemCount: Int) {
        self.partition = partition
        self.itemCount = max(0, itemCount)
    }

    /// 条目数为 0 即空态。
    public var isEmpty: Bool { itemCount == 0 }

    /// 仅当分区允许删除且非空时，才允许执行删除操作。
    public var canDeleteAny: Bool { partition.allowsDelete && !isEmpty }

    /// 空态文案的稳定本地化 key（由 App 层解析为最终文案）。
    public var emptyStateLocalizationKey: String {
        switch partition {
        case .officialLineArt: return "library.empty.official-line-art"
        case .myLineArt: return "library.empty.my-line-art"
        case .history: return "library.empty.history"
        case .imports: return "library.empty.imports"
        }
    }
}
