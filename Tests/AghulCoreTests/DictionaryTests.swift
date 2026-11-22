//
//  DictionaryTests.swift
//  AghulCoreTests
//
//  The SHIPPED artifacts (AghulKeyboardExtension/aghul_words.sqlite
//  and aghul_bigrams.sqlite, built by scripts/build_dictionary.py)
//  through the engine's readers: metadata, counts, the canonical form of
//  every lookup key, prefix suggestions ranked by frequency, next words
//  from real bigrams, the palochka as a letter, and the cleanup rules.
//  The figures are those of cleanup version 1 (docs/DICTIONARY.md).
//

import XCTest
import SQLite3
@testable import AghulCore
@testable import GeneralKeyboard

final class DictionaryTests: AghulTestCase {

    private var words: WordSuggestions!
    private var bigrams: StaticBigrams!

    override func setUpWithError() throws {
        try super.setUpWithError()
        words = try XCTUnwrap(WordSuggestions(databaseURL: RepoPaths.wordsArtifact))
        bigrams = try XCTUnwrap(StaticBigrams(databaseURL: RepoPaths.bigramsArtifact))
    }

    private func meta(_ url: URL) throws -> [String: String] {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT key, value FROM meta", -1, &stmt, nil), SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        var values: [String: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            values[String(cString: sqlite3_column_text(stmt, 0))] = String(cString: sqlite3_column_text(stmt, 1))
        }
        return values
    }

    func testArtifactMetadata() throws {
        let w = try XCTUnwrap(words.metadata)
        XCTAssertEqual(w.artifact, "aghul_words")
        XCTAssertEqual(w.schemaVersion, 1)
        XCTAssertEqual(w.contentVersion, 1)
        XCTAssertEqual(w.normalizationVersion, Normalization.version)
        XCTAssertEqual(w.minReaderSchema, 1)
        XCTAssertEqual(w.rowCount, 7493)
        let b = try XCTUnwrap(bigrams.metadata)
        XCTAssertEqual(b.artifact, "aghul_bigrams")
        XCTAssertEqual(b.rowCount, 1625)
        XCTAssertEqual(b.normalizationVersion, Normalization.version)
        XCTAssertFalse(bigrams.isEmpty)
        // Both artifacts name the profile they are canonical under
        for url in [RepoPaths.wordsArtifact, RepoPaths.bigramsArtifact] {
            let values = try meta(url)
            XCTAssertEqual(values["normalization_profile"], KeyboardDefinition.current.normalization.id)
            XCTAssertEqual(values["normalization_profile"], "aghul-cyrillic")
            XCTAssertEqual(values["language"], "agx")
            XCTAssertEqual(values["cleanup_version"], "1")
        }
    }

    /// Every stored key is already canonical (lowercase, NFC, palochka
    /// U+04CF), valid under the token contract and written with Aghul
    /// letters only, and every bigram word is a row of the words artifact,
    /// so a lookup never misses by representation.
    func testEveryRowIsCanonicalAndValid() throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(RepoPaths.wordsArtifact.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT word, base_score FROM words", -1, &stmt, nil), SQLITE_OK)
        var all = Set<String>()
        var minScore = Int.max
        var withPalochka = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let word = String(cString: sqlite3_column_text(stmt, 0))
            minScore = min(minScore, Int(sqlite3_column_int64(stmt, 1)))
            XCTAssertTrue(Normalization.isCanonical(word), word)
            XCTAssertTrue(Normalization.isValidToken(word), word)
            XCTAssertFalse(word.contains(Aghul.visible), "\(word) stores the visible palochka U+04C0")
            XCTAssertFalse(word.contains("\u{04CF}\u{04CF}"), "\(word) has a doubled palochka")
            let letters = word.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "\u{04CF}", with: "")
            XCTAssertTrue(Aghul.isAghulText(letters), word)
            withPalochka += word.contains(Aghul.lookup) ? 1 : 0
            all.insert(word)
        }
        sqlite3_finalize(stmt)
        XCTAssertEqual(all.count, 7493)
        XCTAssertEqual(withPalochka, 2053)
        XCTAssertGreaterThanOrEqual(minScore, 1)

        var bdb: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(RepoPaths.bigramsArtifact.path, &bdb, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(bdb) }
        XCTAssertEqual(sqlite3_prepare_v2(bdb, "SELECT prev, word, weight FROM bigrams", -1, &stmt, nil), SQLITE_OK)
        var pairs = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let prev = String(cString: sqlite3_column_text(stmt, 0))
            let word = String(cString: sqlite3_column_text(stmt, 1))
            XCTAssertTrue(all.contains(prev), prev)
            XCTAssertTrue(all.contains(word), word)
            XCTAssertGreaterThanOrEqual(sqlite3_column_int64(stmt, 2), 2)
            pairs += 1
        }
        sqlite3_finalize(stmt)
        XCTAssertEqual(pairs, 1625)
    }

    /// Frequency ranks the prefix candidates, for prefixes that end inside
    /// or right after a two-character letter, and for the palochka as a
    /// letter of its own at the start of a word.
    func testPrefixSuggestionsAreRankedByFrequency() {
        XCTAssertEqual(words.suggestions(for: "агъ"), ["агъай", "агъа", "агъая"])
        XCTAssertEqual(words.suggestions(for: "ӏ"), ["ӏисайи", "ӏиса", "ӏисайин"])
        XCTAssertEqual(words.suggestions(for: "ӏу"), ["ӏу", "ӏуьмур", "ӏуьтӏанас"])
        XCTAssertEqual(words.suggestions(for: "кӏ"), ["кӏилди", "кӏиркӏ", "кӏина"])
        XCTAssertEqual(words.suggestions(for: "хӏ"), ["хӏа", "хӏаф", "хӏавел"])
        XCTAssertEqual(words.suggestions(for: "гӏ"), ["гӏедат", "гӏанаъ", "гӏучӏуна"])
        XCTAssertEqual(words.suggestions(for: "тӏ"), ["тӏалаб", "тӏибитӏарин", "тӏунаъ"])
        XCTAssertEqual(words.suggestions(for: "чӏ"), ["чӏукь", "чӏал", "чӏирхӏ"])
        XCTAssertEqual(words.suggestions(for: "цӏ"), ["цӏеӏу", "цӏае", "цӏа"])
        XCTAssertEqual(words.suggestions(for: "гъ"), ["гъил", "гъушуная", "гъузуна"])
        XCTAssertEqual(words.suggestions(for: "гь"), ["гьеге", "гьикуная", "гьал"])
        XCTAssertEqual(words.suggestions(for: "хъ"), ["хъара", "хъая", "хъай"])
        XCTAssertEqual(words.suggestions(for: "хь"), ["хьуная", "хьуна", "хьасе"])
        XCTAssertEqual(words.suggestions(for: "кь"), ["кьабул", "кьуват", "кьабахъай"])
        XCTAssertEqual(words.suggestions(for: "дж"), ["джалла", "джан", "джуваб"])
        XCTAssertEqual(words.suggestions(for: "тт"), ["ттур", "ттуттанасе", "ттура"])
        XCTAssertEqual(words.suggestions(for: "кк"), ["кканди", "ккандея", "кканде"])
        XCTAssertEqual(words.suggestions(for: "пп"), ["ппара", "ппай", "ппараттар"])
        XCTAssertEqual(words.suggestions(for: "э"), ["эесси", "экьуна", "эв"])
        XCTAssertEqual(words.suggestions(for: "юркӏ"), ["юркӏв", "юркӏураъ", "юркӏвар"])
        // The text has no word with «щ» or «ы»
        XCTAssertEqual(words.suggestions(for: "щ"), [])
        XCTAssertEqual(words.suggestions(for: "ы"), [])
        XCTAssertEqual(words.suggestions(for: "ъъъ"), [])
    }

    /// A prefix typed with the keyboard's Ӏ (U+04C0), in capitals, with the
    /// Latin I that other keyboards and the AgulLang dictionary use, or in
    /// decomposed Unicode reaches the same rows.
    func testPrefixLookupNormalizesThePalochka() {
        let canonical = words.suggestions(for: "кӏил")
        XCTAssertEqual(canonical.first, "кӏилди")
        XCTAssertEqual(words.suggestions(for: "к\u{04C0}ил"), canonical)      // U+04C0
        XCTAssertEqual(words.suggestions(for: "К\u{04C0}ИЛ"), canonical)
        XCTAssertEqual(words.suggestions(for: "кIил"), canonical)             // Latin I
        XCTAssertEqual(words.suggestions(for: "kIил"), canonical)             // Latin k and I
        XCTAssertEqual(words.suggestions(for: "\u{04C0}иса"), words.suggestions(for: "ӏиса"))
        XCTAssertEqual(words.suggestions(for: "Iиса"), words.suggestions(for: "ӏиса"))
        XCTAssertTrue(words.contains("\u{04C0}исайи"))
        XCTAssertTrue(words.contains("Г\u{04C0}УЧ\u{04C0}УНА"))
        XCTAssertTrue(words.contains("хьуная"))
        XCTAssertEqual(words.suggestions(for: "\u{04C0}исаи\u{0306}"), words.suggestions(for: "ӏисай"))
    }

    /// The palochka is a letter of Aghul: words made of it and one more
    /// letter are rows, which the built-in Dagestanian profile would refuse.
    func testThePalochkaCountsAsALetter() {
        XCTAssertTrue(words.contains("ӏу"))        // "two", 45 times in Luke; dropped by v0 (rule R1)
        XCTAssertTrue(words.contains("ӏа"))
        XCTAssertTrue(words.contains("яӏ"))        // AgulLang «яI» (rule W1)
        XCTAssertEqual(Normalization.letterCount("ӏу"), 2)
        XCTAssertTrue(Normalization.isValidToken("ӏу"))
        XCTAssertFalse(Normalization.isValidToken("ӏ"))
        XCTAssertEqual(words.suggestions(for: "ӏу").first, "ӏу")
    }

    /// The fixes of cleanup version 1 (docs/DICTIONARY.md).
    func testCleanupRulesAreApplied() {
        // G1: two words of Luke printed as one, split at the capital
        for (glued, parts) in [("хьунаяаллагьди", ["хьуная", "аллагьди"]),
                               ("варфаламейматфей", ["варфаламей", "матфей"]),
                               ("акьасхъуттурфуна", ["акьас", "хъуттурфуна"])] {
            XCTAssertFalse(words.contains(glued), glued)
            for part in parts { XCTAssertTrue(words.contains(part), part) }
        }
        // G2: the same before the name «Ӏиса»
        XCTAssertFalse(words.contains("гъушанасӏисайис"))
        XCTAssertFalse(words.contains("эӏисайи"))
        XCTAssertTrue(words.contains("гъушанас"));       XCTAssertTrue(words.contains("ӏисайис"))
        // W1 / P1: AgulLang words v0 cut at the Latin-I palochka
        for (word, pieces) in [("алирхӏас", ["алирх"]), ("кӏечӏ", ["еч"]), ("гӏабдал", ["абдал"]),
                               ("ӏекьраб", ["екьраб"]), ("йиркӏв", ["йирк"])] {
            XCTAssertTrue(words.contains(word), word)
            for piece in pieces { XCTAssertFalse(words.contains(piece), piece) }
        }
        // … a piece that is also a word of Luke stays
        XCTAssertTrue(words.contains("вас"));            XCTAssertTrue(words.contains("ме"))
        // F1: suffix notations of noun entries are not words
        for notation in ["ар", "ди", "бур", "йи", "ура"] {
            XCTAssertFalse(words.contains(notation), notation)
        }
        // S1: the IDS «ъӀ» merged into the alphabet's «Ӏ» where that word is a row
        XCTAssertFalse(words.contains("ъӏуд"));          XCTAssertTrue(words.contains("ӏуд"))
        XCTAssertFalse(words.contains("лиъӏ"));          XCTAssertTrue(words.contains("лиӏ"))
    }

    /// What the rules deliberately leave alone.
    func testNothingElseWasRespelledOrRemoved() {
        // «ъӀ» with no «Ӏ» twin in the data: kept and flagged, not respelled
        XCTAssertTrue(words.contains("ъӏадат"))
        XCTAssertFalse(words.contains("ӏадат"))
        // «хъӀ» is a pharyngealized «хъ», not «хӀ»: never merged
        XCTAssertTrue(words.contains("хъӏал"))
        XCTAssertTrue(words.contains("хӏал"))
        // No capital proves these: flagged as possibly glued, not split
        XCTAssertTrue(words.contains("пунапуная"))
        XCTAssertTrue(words.contains("инсанаргебурис"))
        // Suffixes and compound verbs written as one word are words
        XCTAssertTrue(words.contains("ӏисайифас"))
        XCTAssertTrue(words.contains("ягӏархьуна"))
        // Doubled consonants are letters of Aghul: «кк» and «к» make different words
        XCTAssertTrue(words.contains("ккея"));           XCTAssertTrue(words.contains("кея"))
        XCTAssertTrue(words.contains("ппара"))
        // Hyphenated dictionary entries, and a possible suffix notation, stay
        XCTAssertTrue(words.contains("дад-баб"))
        XCTAssertTrue(words.contains("вар"))
        // The self-name of the language
        XCTAssertTrue(words.contains("агъул"));          XCTAssertTrue(words.contains("чӏал"))
    }

    func testNextWordsComeFromRealBigrams() {
        XCTAssertEqual(bigrams.nextWords(after: "ӏисайи"), ["пуная", "ахъакьуная", "хабар"])
        XCTAssertEqual(bigrams.nextWords(after: "зун"), ["чвас", "вас", "ме"])
        XCTAssertEqual(bigrams.nextWords(after: "хабар"), ["гъушуная", "акьуна", "акьас"])
        XCTAssertEqual(bigrams.nextWords(after: "аллагьдин"), ["паччагьвел", "гаф", "хулаъ"])
        XCTAssertEqual(bigrams.nextWords(after: "инсандин"), ["кӏиркӏ", "кӏиркӏахъас", "кӏиркӏан"])
        XCTAssertEqual(bigrams.nextWords(after: "\u{04C0}исайи"), ["пуная", "ахъакьуная", "хабар"])
        XCTAssertEqual(bigrams.nextWords(after: "ГӀучӀуна".replacingOccurrences(of: "Ӏ", with: "\u{04C0}")),
                       ["гӏайчӏва"])
        XCTAssertEqual(bigrams.nextWords(after: "ъъъ"), [])
        // Static context reorders dictionary candidates among themselves
        let weights = bigrams.weights(after: "аллагьдин", candidates: ["гаф", "паччагьвел", "ъъъ"])
        XCTAssertEqual(weights, ["паччагьвел": 19, "гаф": 18])
    }

    func testRandomIdleWordsComeFromTheDictionary() {
        let idle = words.randomWords(3)
        XCTAssertEqual(idle.count, 3)
        for word in idle { XCTAssertTrue(words.contains(word), word) }
    }
}
