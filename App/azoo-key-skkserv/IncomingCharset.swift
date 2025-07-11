// SPDX-License-Identifier: MIT

import Foundation

// 文字コードオプション
public enum IncomingCharset: String, CaseIterable {
    case utf8 = "UTF-8"
    case eucjp = "EUC-JP"

    var stringEncoding: String.Encoding {
        switch self {
            case .utf8: return .utf8
            case .eucjp: return .japaneseEUC
        }
    }
}
