//
//  KCAppCompositionRoot.swift
//  KidCanvas
//
//  Created by 小大 on 2026/06/26.
//

import Foundation

/// App 壳层的 Composition Root：集中装配 App 级依赖（会话服务、内容/绘制适配器等），
/// 并通过构造注入交给使用方（当前仅 `KCMainViewController`）。
///
/// 当前阶段保持显式依赖，不引入 DI 容器或全局 Service Locator。
/// 后续业务模块（用户、付费、内容）演进时，在此处统一装配，使用方只接收已构造好的依赖。
final class KCAppCompositionRoot {
    private let sessionService: KCSessionService

    init() {
        // 会话服务：内部装配 Swift KCSessionStore + 旧 archive 迁移器。
        self.sessionService = KCSessionService()
    }

    /// 创建主控制器并注入已装配的依赖。
    func makeMainViewController() -> KCMainViewController {
        KCMainViewController(sessionService: sessionService)
    }
}
