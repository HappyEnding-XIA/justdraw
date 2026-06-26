//
//  KCError.swift
//  KCCommon
//
//  Created by 小大 on 2026/06/25.
//

import Foundation

/// KidCanvas 各模块共用的错误类型。
///
/// 各模块通过同一个描述性的枚举来暴露失败，使 app 外壳和功能层
/// 可以针对已知 case 进行 switch，而无需导入每个模块各自定制的错误类型。
public enum KCError: Error, Equatable, Sendable {
    /// 无法定位所需的文件或目录。
    case missingResource(String)
    /// I/O 操作（读/写/移动）失败。
    case ioFailure(String)
    /// 磁盘上的数据无法解码为期望的类型。
    case decodingFailed(String)
    /// 输入未通过前置条件校验（非法图片、空标识符等）。
    case invalidInput(String)
    /// 检测到旧版格式，但本模块无法完成迁移。
    case legacyMigrationDeferred(String)
}
