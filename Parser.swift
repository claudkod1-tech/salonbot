import Foundation
import CoreXLSX

struct Contact: Codable, Identifiable, Hashable {
    var id: String { username.lowercased() }
    let name: String
    let city: String
    let username: String
}

enum ParseError: LocalizedError {
    case cannotOpen, empty, noHeader
    var errorDescription: String? {
        switch self {
        case .cannotOpen: return "Не удалось открыть файл"
        case .empty: return "Таблица пустая"
        case .noHeader: return "Не найдена колонка Telegram / username / ник"
        }
    }
}

private func columnIndex(_ ref: ColumnReference) -> Int {
    var n = 0
    for u in ref.value.uppercased().unicodeScalars { n = n * 26 + Int(u.value) - 64 }
    return n - 1
}

func extractUsername(_ raw: String) -> String {
    let v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let patterns = [
        #"(?:https?://)?(?:www\.)?(?:t\.me|telegram\.me)/@?([A-Za-z0-9_]{4,32})"#,
        #"^@?([A-Za-z0-9_]{4,32})$"#
    ]
    for p in patterns {
        if let re = try? NSRegularExpression(pattern: p, options: .caseInsensitive),
           let m = re.firstMatch(in: v, range: NSRange(v.startIndex..., in: v)),
           let r = Range(m.range(at: 1), in: v) {
            return String(v[r])
        }
    }
    return ""
}

func parseXLSX(data: Data) throws -> [Contact] {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("import.xlsx")
    try data.write(to: tmp)
    guard let file = XLSXFile(filepath: tmp.path) else { throw ParseError.cannotOpen }

    let shared: SharedStrings? = try file.parseSharedStrings()
    guard let path = try file.parseWorksheetPaths().first else { throw ParseError.empty }
    let ws = try file.parseWorksheet(at: path)

    // each row -> [columnIndex: text]
    let table: [[Int: String]] = (ws.data?.rows ?? []).map { row in
        var d: [Int: String] = [:]
        for c in row.cells {
            var t = ""
            if let s = shared, let v = c.stringValue(s) { t = v } else { t = c.value ?? "" }
            d[columnIndex(c.reference.column)] = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return d
    }
    if table.isEmpty { throw ParseError.empty }

    let tgNames: Set<String> = ["telegram", "телеграм", "username", "ник"]
    guard let hi = table.firstIndex(where: { $0.values.contains { tgNames.contains($0.lowercased()) } })
    else { throw ParseError.noHeader }

    func find(_ names: Set<String>) -> Int? {
        table[hi].first { names.contains($0.value.lowercased()) }?.key
    }
    let iName = find(["название", "name", "имя"])
    let iCity = find(["город", "city"])
    guard let iTg = find(tgNames) else { throw ParseError.noHeader }

    var seen = Set<String>()
    var result: [Contact] = []
    for row in table[(hi + 1)...] {
        let user = extractUsername(row[iTg] ?? "")
        if user.isEmpty || user.lowercased().hasSuffix("bot") { continue }
        if !seen.insert(user.lowercased()).inserted { continue }
        let name = iName.flatMap { row[$0] } ?? ""
        result.append(Contact(name: name.isEmpty ? user : name,
                              city: iCity.flatMap { row[$0] } ?? "",
                              username: user))
    }
    return result
}
