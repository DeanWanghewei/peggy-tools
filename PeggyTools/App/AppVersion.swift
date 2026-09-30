//
//  AppVersion.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

/// 应用版本号的唯一来源。
/// 本地开发时为手写值；正式发版时由 scripts/package-app.sh 按 git tag（vX.Y.Z）重新生成。
enum AppVersion {
    static let current = "1.0.0"
}
