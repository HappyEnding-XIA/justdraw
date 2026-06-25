//
//  KCArtworkSession.swift
//  KCDomain
//
//  Created by 小大 on 2026/06/25.
//

import Foundation

public struct KCArtworkSession: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var title: String
    public var artworkFileName: String
    public var thumbnailFileName: String
    public var modifiedAt: Date

    public init(
        id: String,
        title: String,
        artworkFileName: String,
        thumbnailFileName: String,
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.artworkFileName = artworkFileName
        self.thumbnailFileName = thumbnailFileName
        self.modifiedAt = modifiedAt
    }
}
