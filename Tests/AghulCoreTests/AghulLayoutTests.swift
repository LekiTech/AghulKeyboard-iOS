//
//  AghulLayoutTests.swift
//  AghulCoreTests
//
//  AghulLayout.swift: the three letter rows, the two departures from the
//  Russian iOS layout (checked against the pinned transcription of that
//  layout, Fixtures/agisight/rus-3-rows.yaml), every long-press mapping,
//  what the pinned Agisight Aghul files do and do not contain, the
//  alphabet, and the evidence the design rests on, measured again from the
//  shipped dictionary.
//

import XCTest
import SQLite3
import UIKit
@testable import AghulCore
@testable import GeneralKeyboard

final class AghulLayoutTests: AghulTestCase {

    private var spec: LayoutStyleSpec { KeyboardDefinition.current.layout.spec(for: .standard) }
    private let palochka = String(Aghul.visible)

    private func characters(_ row: [KeyCap]) -> [String] {
        row.compactMap { if case .character(let c) = $0 { return c } else { return nil } }
    }

    private var letterKeys: [String] { spec.letterRows.flatMap(characters) }

    // MARK: - Minimal readers for the pinned files

    private func file(_ name: String) throws -> String {
        try RepoPaths.text(RepoPaths.upstream.appendingPathComponent(name))
    }

    /// Rows of one layer of `iOS: primary:` as key tokens; `\s{…}`
    /// specials (shift, backspace, spacers) are dropped.
    private func russianLayer(_ name: String) throws -> [[String]] {
        let lines = try file("rus-3-rows.yaml").components(separatedBy: "\n")
        guard let primary = lines.firstIndex(of: "  primary:"),
              let start = lines[primary...].firstIndex(where: {
                  $0.trimmingCharacters(in: .whitespaces) == "\(name): |" }) else {
            XCTFail("layer \(name) not found"); return []
        }
        let indent = lines[start].prefix(while: { $0 == " " }).count
        var rows: [[String]] = []
        for line in lines[(start + 1)...] {
            let lineIndent = line.prefix(while: { $0 == " " }).count
            if line.trimmingCharacters(in: .whitespaces).isEmpty || lineIndent <= indent { break }
            rows.append(line.split(separator: " ").map(String.init).filter { !$0.hasPrefix("\\s{") })
        }
        return rows
    }

    // MARK: - Letter rows

    func testLetterRows() {
        XCTAssertEqual(spec.letterRows.map(characters), [
            ["й", "ц", "у", "к", "е", "н", "г", "ш", "ъ", "з", "х"],
            ["ф", "\u{04C0}", "в", "а", "п", "р", "о", "л", "д", "ж", "э"],
            ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю"],
        ])
        XCTAssertEqual(spec.letterRows.count, 3)
        // Shift and backspace frame the third row
        XCTAssertEqual(spec.letterRows[2].first, .shift)
        XCTAssertEqual(spec.letterRows[2].last, .backspace)
        // No letter twice, no row wider than the Russian keyboard's 11 keys
        XCTAssertEqual(Set(letterKeys).count, letterKeys.count)
        XCTAssertEqual(spec.letterRows.map { characters($0).count }, [11, 11, 9])
        // Every key is one Cyrillic character; the palochka is U+04C0
        for key in letterKeys {
            XCTAssertEqual(key.unicodeScalars.count, 1, key)
            XCTAssertTrue(Aghul.isAghulText(key), key)
        }
        XCTAssertEqual(letterKeys.filter { $0 == palochka }.count, 1)
        XCTAssertEqual(Array(palochka.unicodeScalars).map(\.value), [0x04C0])
        XCTAssertFalse(letterKeys.contains("\u{04CF}"))
        XCTAssertFalse(letterKeys.contains("I"))
        XCTAssertFalse(letterKeys.contains("l"))
    }

    /// The layout is the Russian iOS layout with exactly two keys changed:
    /// «ъ» where the Russian keyboard has «щ», «Ӏ» where it has «ы».
    func testOnlyTwoKeysDifferFromTheRussianLayout() throws {
        let russian = try russianLayer("default")
        XCTAssertEqual(russian.map(\.count), [11, 11, 9])
        let aghul = spec.letterRows.map(characters)
        var differences: [String: String] = [:]
        for (r, row) in russian.enumerated() {
            for (i, key) in row.enumerated() where aghul[r][i] != key {
                differences[key] = aghul[r][i]
            }
        }
        XCTAssertEqual(differences, ["щ": "ъ", "ы": palochka])
        // «Ӏ» sits under «ц», next to «ф»
        XCTAssertEqual(aghul[1].firstIndex(of: palochka), 1)
        XCTAssertEqual(aghul[0].firstIndex(of: "ц"), 1)
        // «ъ» sits between «ш» and «з», two keys from «г» and from «х»
        XCTAssertEqual(aghul[0].firstIndex(of: "ъ"), 8)
        XCTAssertEqual(aghul[0].firstIndex(of: "г"), 6)
        XCTAssertEqual(aghul[0].firstIndex(of: "х"), 10)
        // «э», the first letter of native words («эесси»), keeps its key
        XCTAssertEqual(aghul[1].firstIndex(of: "э"), 10)
        XCTAssertEqual(russian[1].firstIndex(of: "э"), 10)
    }

    /// The shift layer the engine derives equals the Russian shift layer
    /// with the same two changes; the palochka has no other case.
    func testShiftLayer() throws {
        let upstream = try russianLayer("shift")
        let shifted = spec.letterRows.map { row in
            characters(row).map { KeyboardLayout.label(for: .character($0), shifted: true, capsLock: false) }
        }
        XCTAssertEqual(shifted, upstream.map { $0.map { $0 == "Щ" ? "Ъ" : $0 == "Ы" ? palochka : $0 } })
        for capsLock in [false, true] {
            XCTAssertEqual(KeyboardLayout.label(for: .character(palochka), shifted: true, capsLock: capsLock), palochka)
        }
    }

    // MARK: - Number and symbol pages

    /// The pages of the Russian iOS keyboard, unchanged. The transcription
    /// writes the typographic “ and ’; the keyboard types the plain " and '
    /// like the sibling keyboards and offers the typographic ones on a
    /// long press.
    func testNumberAndSymbolPagesAreTheRussianOnes() throws {
        func plain(_ rows: [[String]]) -> [[String]] {
            rows.map { $0.map { $0 == "“" ? "\"" : $0 == "’" ? "'" : $0 } }
        }
        XCTAssertEqual(spec.numberRows.map(characters), plain(try russianLayer("symbols-1")))
        XCTAssertEqual(spec.symbolRows.map(characters), plain(try russianLayer("symbols-2")))
        XCTAssertEqual(spec.numberRows[2].first, .symbols)
        XCTAssertEqual(spec.symbolRows[2].first, .numbers)
        XCTAssertEqual(spec.numberRows[2].last, .backspace)
    }

    // MARK: - Long press

    func testLongPressMappings() {
        let p = palochka
        let letters: [String: [String]] = [
            "г": ["гъ", "гь", "г" + p],
            "д": ["дж"],
            "к": ["кь", "к" + p, "къ"],
            "п": ["п" + p],
            "т": ["т" + p],
            "у": ["уь"],
            "х": ["хь", "хъ", "х" + p],
            "ц": ["ц" + p],
            "ч": ["ч" + p],
            "е": ["ё"],
            "ш": ["щ"],
            p: ["ы"],
        ]
        for (key, alternates) in letters {
            XCTAssertEqual(spec.callouts[key], alternates, key)
        }
        // No other letter key has a long press: not «ъ», «ь» or «ж»
        let letterCalloutKeys = spec.callouts.keys.filter { $0.first!.isLetter }
        XCTAssertEqual(Set(letterCalloutKeys), Set(letters.keys))
        // Every long-press base is a key of the layout, and no option
        // repeats its base key or another option
        let allKeys = Set((spec.letterRows + spec.numberRows + spec.symbolRows).flatMap(characters))
        for (key, alternates) in spec.callouts {
            XCTAssertTrue(allKeys.contains(key), "\(key) is not a key")
            XCTAssertFalse(alternates.contains(key), key)
            XCTAssertEqual(Set(alternates).count, alternates.count, key)
        }
        // No popup is wider than the base key and three options
        XCTAssertLessThanOrEqual(letters.values.map(\.count).max()!, 3)
    }

    /// Each digraph option is exactly two Cyrillic characters that start
    /// with its base key: a sequence, never a single code point, a Latin
    /// lookalike or the lookup palochka.
    func testDigraphOptionsInsertTheIntendedUnicodeSequences() {
        var offered: [String] = []
        for (key, alternates) in AghulLayout.digraphCallouts {
            for option in alternates {
                XCTAssertEqual(option.unicodeScalars.count, 2, option)
                XCTAssertEqual(option.count, 2, option)
                XCTAssertTrue(option.hasPrefix(key), option)
                XCTAssertTrue(Aghul.isAghulText(option), option)
                XCTAssertEqual(option, option.precomposedStringWithCanonicalMapping, option)
                offered.append(option)
            }
        }
        XCTAssertEqual(offered.sorted(), Aghul.digraphs.sorted())
        let expected: [[UInt32]] = [
            [0x0433, 0x044A], [0x0433, 0x044C], [0x0433, 0x04C0],   // гъ гь гӀ
            [0x0434, 0x0436],                                       // дж
            [0x043A, 0x044A], [0x043A, 0x044C], [0x043A, 0x04C0],   // къ кь кӀ
            [0x043F, 0x04C0], [0x0442, 0x04C0], [0x0443, 0x044C],   // пӀ тӀ уь
            [0x0445, 0x044A], [0x0445, 0x044C], [0x0445, 0x04C0],   // хъ хь хӀ
            [0x0446, 0x04C0], [0x0447, 0x04C0],                     // цӀ чӀ
        ]
        XCTAssertEqual(expected.count, 15)
        XCTAssertEqual(Set(offered.map { Array($0.unicodeScalars).map(\.value) }), Set(expected))
        // The displaced Russian letters are single Cyrillic letters
        XCTAssertEqual(Array(spec.callouts[palochka]![0].unicodeScalars).map(\.value), [0x044B])   // ы
        XCTAssertEqual(Array(spec.callouts["ш"]![0].unicodeScalars).map(\.value), [0x0449])        // щ
        XCTAssertEqual(Array(spec.callouts["е"]![0].unicodeScalars).map(\.value), [0x0451])        // ё
    }

    /// What Agisight/rf-keyboard-corpora has for Aghul, and what the
    /// keyboard makes of it. The layout file is an empty stub, so there
    /// was no layout to follow. Its two mappings are long presses for the
    /// Russian keyboard: the basic one puts the palochka under «ь» (not
    /// taken: the palochka has its own key here); the extended one lists
    /// the two-character letters under their first letter, which the
    /// callouts follow, except that the doubled letters are typed by a
    /// double tap and «дж» sits under «д», not «ж». Its palochka is U+04C0.
    func testPinnedAgisightAghulFiles() throws {
        let stub = try Data(contentsOf: RepoPaths.upstream.appendingPathComponent("agx_key_default.json"))
        let layout = try XCTUnwrap(JSONSerialization.jsonObject(with: stub) as? [String: Any])
        XCTAssertEqual((layout["keys"] as? [Any])?.count, 0)
        XCTAssertEqual((layout["long_press"] as? [Any])?.count, 0)

        let data = try Data(contentsOf: RepoPaths.upstream.appendingPathComponent("agx_key_mapping.json"))
        let mapping = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: [String]])
        XCTAssertEqual(mapping, ["Ь": [palochka]])
        XCTAssertEqual(Array(mapping["Ь"]![0].unicodeScalars).map(\.value), [0x04C0])
        XCTAssertNil(spec.callouts["ь"])
        XCTAssertTrue(letterKeys.contains(palochka))

        let extData = try Data(contentsOf: RepoPaths.upstream.appendingPathComponent("agx_key_mapping_ext.json"))
        let ext = try XCTUnwrap(JSONSerialization.jsonObject(with: extData) as? [String: [String]])
        XCTAssertEqual(Set(ext.keys), ["Г", "Ж", "К", "П", "Т", "У", "Х", "Ц", "Ч", "Ь"])
        var upstreamDoubled: [String] = []
        for base in ["Г", "К", "П", "Т", "У", "Х", "Ц", "Ч"] {
            let options = ext[base]!
            let doubled = options.filter { $0 == base + base }
            upstreamDoubled += doubled
            let ours = AghulLayout.digraphCallouts[base.lowercased()]!.map { option in
                // uppercase as upstream writes it; the palochka has one form
                option.uppercased()
            }
            XCTAssertEqual(Set(options).subtracting(doubled), Set(ours), base)
        }
        XCTAssertEqual(upstreamDoubled.sorted(), Aghul.doubled.map { $0.uppercased() }.sorted())
        XCTAssertEqual(ext["Ж"], ["ДЖ"])
        XCTAssertEqual(AghulLayout.digraphCallouts["д"], ["дж"])
        XCTAssertNil(spec.callouts["ж"])
    }

    /// The symbol alternates are those of the Russian iOS keyboard.
    func testSymbolLongPressesAreTheRussianOnes() throws {
        var upstream: [String: [String]] = [:]
        for line in try file("rus-longpress.yaml").components(separatedBy: "\n") {
            guard let colon = line.range(of: ": ") else { continue }
            func unquote(_ s: Substring) -> String {
                let t = s.trimmingCharacters(in: .whitespaces)
                if t.count >= 2, let f = t.first, f == t.last, f == "'" || f == "\"" {
                    return String(t.dropFirst().dropLast())
                }
                return t
            }
            upstream[unquote(line[..<colon.lowerBound])] =
                unquote(line[colon.upperBound...]).split(separator: " ").map(String.init)
        }
        XCTAssertEqual(upstream["е"], spec.callouts["е"])
        for key in ["0", "₽", "#", ".", "%", "=", "-", "/", "&", "?", "!"] {
            XCTAssertEqual(spec.callouts[key], upstream[key], key)
        }
        // The quote alternates sit on this layout's ' and " keys; the
        // popup never repeats its base key
        XCTAssertEqual(spec.callouts["'"], upstream["’"]?.filter { $0 != "'" })
        XCTAssertEqual(spec.callouts["\""], upstream["“"]?.filter { $0 != "\"" })
    }

    // MARK: - Alphabet

    /// Every one of the 53 entries of the Aghul alphabet of 1990 (as the
    /// Great Russian Encyclopedia, the Russian and English Wikipedia and
    /// the Institute of Linguistics print it) can be typed.
    func testWholeAlphabetIsTypeable() {
        let p = palochka
        let alphabet = ["а", "б", "в", "г", "гъ", "гь", "г" + p, "д", "дж", "е", "ё", "ж", "з", "и", "й",
                        "к", "кк", "къ", "кь", "к" + p, "л", "м", "н", "о", "п", "пп", "п" + p, "р", "с",
                        "т", "тт", "т" + p, "у", "уь", "ф", "х", "хъ", "хь", "х" + p, "ц", "ц" + p,
                        "ч", "чч", "ч" + p, "ш", "щ", "ъ", p, "ы", "ь", "э", "ю", "я"]
        XCTAssertEqual(alphabet.count, 53)
        XCTAssertEqual(Set(alphabet).count, 53)
        let keys = Set(letterKeys)
        let longPress = Set(spec.callouts.filter { keys.contains($0.key) }.flatMap(\.value))
        for letter in alphabet {
            let fromKeys = letter.allSatisfy { keys.contains(String($0)) }
            XCTAssertTrue(fromKeys || longPress.contains(letter), "\(letter) cannot be typed")
        }
        // The palochka, a letter of its own, is a key
        XCTAssertTrue(keys.contains(p))
        // Every digraph both ways: key by key, and as one long press
        for digraph in Aghul.digraphs {
            XCTAssertTrue(alphabet.contains(digraph), digraph)
            XCTAssertTrue(digraph.allSatisfy { keys.contains(String($0)) }, digraph)
            XCTAssertTrue(longPress.contains(digraph), digraph)
        }
        // The doubled letters need no long press: the letter is a key
        for sequence in Aghul.doubled {
            XCTAssertTrue(alphabet.contains(sequence), sequence)
            XCTAssertTrue(sequence.allSatisfy { keys.contains(String($0)) }, sequence)
            XCTAssertFalse(longPress.contains(sequence), sequence)
        }
        XCTAssertEqual(Aghul.digraphs.count + Aghul.doubled.count, alphabet.filter { $0.count == 2 }.count)
        // The only Russian letters without a key of their own
        let russian = Set("абвгдеёжзийклмнопрстуфхцчшщъыьэюя".map(String.init))
        XCTAssertEqual(russian.subtracting(keys), ["ё", "щ", "ы"])
        XCTAssertTrue(longPress.isSuperset(of: ["ё", "щ", "ы"]))
        // Nothing is offered twice
        let options = spec.callouts.filter { keys.contains($0.key) }.flatMap(\.value)
        XCTAssertEqual(Set(options).count, options.count)
    }

    // MARK: - The evidence, from the shipped dictionary

    /// The layout rests on measured frequencies (docs/LAYOUT.md). The
    /// claims are checked against the shipped dictionary, so a future
    /// dictionary that no longer supports them fails here.
    func testCorpusFrequenciesSupportTheLayout() throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(RepoPaths.wordsArtifact.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT word, base_score FROM words", -1, &stmt, nil), SQLITE_OK)
        var characters: [Character: Int] = [:]
        var pairs: [String: Int] = [:]
        var palochkaOfItsOwn = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let word = Array(String(cString: sqlite3_column_text(stmt, 0)))
            let count = Int(sqlite3_column_int64(stmt, 1)) / 10
            guard count > 0 else { continue }
            for (i, ch) in word.enumerated() where ch != "-" {
                characters[ch, default: 0] += count
                if i > 0 { pairs[String([word[i - 1], ch]), default: 0] += count }
                if ch == Aghul.lookup, i == 0 || !"гкптхцч".contains(word[i - 1]) { palochkaOfItsOwn += count }
            }
        }
        sqlite3_finalize(stmt)
        let total = Double(characters.values.reduce(0, +))
        func share(_ ch: Character) -> Double { 100 * Double(characters[ch] ?? 0) / total }
        func pair(_ p: String) -> Int { pairs[p.replacingOccurrences(of: "\u{04C0}", with: "\u{04CF}")] ?? 0 }
        let p = palochka

        // The palochka and «ъ» are among the most frequent letters of
        // Aghul text; «щ» and «ы», whose keys they take, do not occur in
        // the running text at all
        XCTAssertEqual(share(Aghul.lookup), 3.24, accuracy: 0.05)
        XCTAssertEqual(share("ъ"), 2.31, accuracy: 0.05)
        XCTAssertEqual(share("ь"), 3.77, accuracy: 0.05)
        XCTAssertEqual(share("щ"), 0)
        XCTAssertEqual(share("ы"), 0)
        // «э» begins native words: it keeps its key, unlike on the Lak keyboard
        XCTAssertEqual(share("э"), 0.18, accuracy: 0.03)
        for ch in "эюжц" {
            XCTAssertGreaterThan(share(ch), 0.05, String(ch))
        }
        // More than a quarter of all palochkas are the letter «Ӏ» itself,
        // not the tail of кӀ хӀ гӀ тӀ чӀ цӀ пӀ
        let palochkaTotal = Double(characters[Aghul.lookup]!)
        XCTAssertEqual(100 * Double(palochkaOfItsOwn) / palochkaTotal, 28.5, accuracy: 1.0)
        // Long-press order on the keys with several digraphs, in Luke: the
        // same as the web count on «к» and «х»
        XCTAssertGreaterThan(pair("кь"), pair("к" + p))
        XCTAssertGreaterThan(pair("к" + p), pair("къ"))
        XCTAssertGreaterThan(pair("хь"), pair("хъ"))
        XCTAssertGreaterThan(pair("хъ"), pair("х" + p))
        // … and on «г» with «гӀ» last; Luke has more «гь» («Аллагь») than «гъ»
        XCTAssertGreaterThan(pair("гь"), pair("г" + p))
        XCTAssertGreaterThan(pair("гъ"), pair("г" + p))
        XCTAssertGreaterThan(pair("гь"), pair("гъ"))
        XCTAssertGreaterThan(pair("уь"), 0)
        XCTAssertGreaterThan(pair("дж"), 0)
    }

    /// The independent letter count of Agisight/rf-keyboard-corpora (web
    /// text, the larger sample) gives the order of the long-press options
    /// and shows the same rare letters.
    func testAgisightLetterCountGivesTheOrder() throws {
        var percent: [String: Double] = [:]
        for line in try file("agx_monocorpus_freq.csv").components(separatedBy: "\n").dropFirst() {
            let fields = line.split(separator: ",")
            guard fields.count == 3, let value = Double(fields[2]) else { continue }
            percent[String(fields[0])] = value
        }
        let p = palochka
        XCTAssertEqual(percent.count, 53)
        XCTAssertGreaterThan(percent["ГЪ"]!, percent["ГЬ"]!)
        XCTAssertGreaterThan(percent["ГЬ"]!, percent["Г" + p]!)
        XCTAssertGreaterThan(percent["КЬ"]!, percent["К" + p]!)
        XCTAssertGreaterThan(percent["К" + p]!, percent["КЪ"]!)
        XCTAssertGreaterThan(percent["ХЬ"]!, percent["ХЪ"]!)
        XCTAssertGreaterThan(percent["ХЪ"]!, percent["Х" + p]!)
        // The palochka on its own is a row of the table
        XCTAssertGreaterThan(percent[p]!, 0.5)
        // «щ», «ы» and «ё» are the rarest letters; «э» is five times «ы»
        XCTAssertLessThan(percent["Щ"]!, 0.05)
        XCTAssertLessThan(percent["Ы"]!, 0.1)
        XCTAssertLessThan(percent["Ё"]!, 0.01)
        XCTAssertGreaterThan(percent["Э"]!, 4 * percent["Ы"]!)
        // Every two-character letter of the alphabet is a row
        for letter in Aghul.digraphs + Aghul.doubled {
            XCTAssertNotNil(percent[letter.uppercased()], letter)
        }
    }
}
