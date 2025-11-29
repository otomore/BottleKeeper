import Foundation

/// 検索可能なオブジェクトのプロトコル
///
/// 検索テキストに基づくフィルタリングを統一的に処理するためのプロトコル。
/// Core Dataエンティティに準拠させることで、検索ロジックを共通化できます。
protocol Filterable {
    /// 検索対象となるテキスト
    var searchableText: String { get }
}

// MARK: - Core Data Entity Extensions

extension Bottle: Filterable {
    /// ボトル名と蒸留所名を検索対象とする
    var searchableText: String {
        "\(wrappedName) \(wrappedDistillery)"
    }
}

extension WishlistItem: Filterable {
    /// ウィッシュリスト項目名と蒸留所名を検索対象とする
    var searchableText: String {
        "\(wrappedName) \(wrappedDistillery)"
    }
}

// MARK: - Collection Extensions

extension Array where Element: Filterable {
    /// 検索テキストでフィルタリング
    ///
    /// - Parameter searchText: 検索テキスト（空の場合は全件返却）
    /// - Returns: フィルタリングされた配列
    func filtered(by searchText: String) -> [Element] {
        guard !searchText.isEmpty else { return self }
        return filter { $0.searchableText.localizedCaseInsensitiveContains(searchText) }
    }
}

extension Sequence where Element: Filterable {
    /// 検索テキストでフィルタリング（Sequenceプロトコル対応）
    ///
    /// FetchedResults等のSequenceにも対応
    ///
    /// - Parameter searchText: 検索テキスト（空の場合は全件返却）
    /// - Returns: フィルタリングされた配列
    func filtered(by searchText: String) -> [Element] {
        guard !searchText.isEmpty else { return Array(self) }
        return filter { $0.searchableText.localizedCaseInsensitiveContains(searchText) }
    }
}
