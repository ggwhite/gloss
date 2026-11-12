import Foundation

/// Everything read from the vault. The vault is never written.
public struct VaultSnapshot: Equatable, Sendable {
    public var decks: [Deck: [VocabEntry]] = [:]
    public var mistakes: [Mistake] = []
    public var problems: [String] = []
    public var loadedAt: Date = .distantPast
    public init() {}

    /// The cards of the decks that are on. A word in several decks is quizzed once (spelling first),
    /// because progress is kept per word.
    public func entries(for decks: Set<Deck>) -> [VocabEntry] {
        var seen = Set<String>()
        return Deck.allCases.filter(decks.contains).flatMap { self.decks[$0] ?? [] }
            .filter { seen.insert($0.word.lowercased()).inserted }
    }
}

public enum Vault {
    public static let defaultPath = "~/ob/英文"
    public static let vocabFile = "單字.md"
    public static let mistakesFolder = "錯誤紀錄"

    /// Expands `~` and follows symlinks.
    public static func resolve(_ path: String) -> URL {
        let expanded = (path.trimmingCharacters(in: .whitespaces) as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).resolvingSymlinksInPath()
    }

    public static func load(path: String, now: Date = Date()) -> VaultSnapshot {
        load(root: resolve(path), now: now)
    }

    public static func load(root: URL, now: Date = Date()) -> VaultSnapshot {
        var snap = VaultSnapshot()
        snap.loadedAt = now
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            snap.problems.append("Vault folder not found: \(root.path)")
            return snap
        }
        if let text = readText(root.appendingPathComponent(vocabFile)) {
            snap.decks = VocabParser.parse(text)
            if snap.decks[.spelling, default: []].isEmpty {
                snap.problems.append("No table found under “## 拼字” in \(vocabFile).")
            }
        } else {
            snap.problems.append("Could not read \(vocabFile).")
        }
        let folder = root.appendingPathComponent(mistakesFolder).resolvingSymlinksInPath()
        if let names = try? fm.contentsOfDirectory(atPath: folder.path) {
            for name in names.sorted() {
                guard let day = MistakeParser.day(fromFileName: name),
                      let text = readText(folder.appendingPathComponent(name)) else { continue }
                snap.mistakes += MistakeParser.parse(text, day: day)
            }
        }
        return snap
    }

    /// Reads a UTF-8 file. When iCloud has not downloaded it yet, asks for a download.
    static func readText(_ url: URL) -> String? {
        if let data = try? Data(contentsOf: url) { return String(decoding: data, as: UTF8.self) }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        return nil
    }

    /// A cheap fingerprint of the files Gloss reads: it changes when any of them changes.
    public static func fingerprint(path: String) -> String {
        let root = resolve(path)
        let fm = FileManager.default
        var parts: [String] = []
        func add(_ url: URL) {
            guard let a = try? fm.attributesOfItem(atPath: url.path) else { return }
            let m = (a[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let s = (a[.size] as? NSNumber)?.intValue ?? 0
            parts.append("\(url.lastPathComponent):\(m):\(s)")
        }
        add(root.appendingPathComponent(vocabFile))
        let folder = root.appendingPathComponent(mistakesFolder).resolvingSymlinksInPath()
        for name in ((try? fm.contentsOfDirectory(atPath: folder.path)) ?? []).sorted() where name.hasSuffix(".md") {
            add(folder.appendingPathComponent(name))
        }
        return parts.joined(separator: "|")
    }
}

/// Made-up words used by the screenshot, the self-test and the README. Not from any real vault.
public enum DemoDeck {
    public static let markdown = """
    # Demo

    ## 拼字（demo）

    | 正確拼法 | 你打的 | 中文 | 記法 | 次數 |
    |---|---|---|---|---|
    | flumbrance | flumberance | 容量 | **flum** + brance，中間沒有 e | 4 |
    | quintavel | quintivel | 閃爍 | quint + **a** + vel | 3 |
    | zorbitude | zorbitute | 耐心 | 結尾是 `-tude` | 2 |
    | plexander | plexender | 承諾 | plex + **and** + er | 1 |
    | snarvelous | snarvelus | 熱鬧的 | 跟 marvelous 一樣有 o | 1 |

    ## 用字（demo）

    | 該用 | 你用的 | 中文 | 差別 | 次數 |
    |---|---|---|---|---|
    | glintwise | glintly | 順便 | glintwise 是副詞 | 1 |
    """

    public static let mistakes = """
    - `a flumbrance` → `the flumbrance` — 特定的那個 #冠詞
    - `quintivel` → `quintavel` — 中間是 a #拼字
    - `he go` → `he goes` — 第三人稱單數 #動詞形式
    """

    public static var snapshot: VaultSnapshot {
        var s = VaultSnapshot()
        s.decks = VocabParser.parse(markdown)
        s.mistakes = MistakeParser.parse(mistakes, day: nil)
        return s
    }
}
