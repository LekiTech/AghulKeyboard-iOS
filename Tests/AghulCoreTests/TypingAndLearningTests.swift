//
//  TypingAndLearningTests.swift
//  AghulCoreTests
//
//  The keyboard model built exactly as the extension builds it (its own
//  UserDefaults, its own learned store), fed through a mock host: the keys
//  and the long-press options insert Aghul letters and digraphs with
//  the palochka Ӏ U+04C0 in lowercase, title case and uppercase, typed and
//  picked words are learned under the lookup form and come back in the
//  visible one, settings persist, the default learning speed is Normal. The bundled
//  artifacts are not in the test bundle, so the model's dictionary tier is
//  empty here; the dictionary itself is covered by DictionaryTests. Every
//  word is a real word of the Aghul dictionary.
//

import XCTest
import UIKit
@testable import AghulCore
@testable import GeneralKeyboard

final class TypingAndLearningTests: AghulTestCase {

    private static let persistedKeys = [
        "layoutStyle", "recentEmojis",
        "set_wordSuggestions", "set_nextWordSuggestions", "set_autoSpaceAfterSuggestion",
        "set_doubleSpacePeriod", "set_spaceCursor", "set_spaceLabel",
        "set_learnSpeed", "set_calloutDelay", "set_theme",
    ]

    override func setUp() {
        super.setUp()
        for key in Self.persistedKeys { UserDefaults.standard.removeObject(forKey: key) }
        // Empty the learned store IN PLACE; never delete learned.sqlite
        // while a model may still hold it open.
        LearnedWords()?.reset()
        // These tests follow a word from its first use, so they run with
        // Fast selected, the way a user picks it in the settings panel.
        // The default (Normal, three uses) has its own tests under
        // "Learning speed", which start without a stored choice.
        UserDefaults.standard.set("fast", forKey: "set_learnSpeed")
    }

    @MainActor
    private func type(_ text: String, into model: KeyboardModel, proxy: MockTextDocumentProxy) {
        for ch in text {
            model.handleKey(ch == " " ? .space : .character(String(ch)), proxy: proxy)
            model.updateSuggestions(proxy: proxy)
        }
    }

    /// What the keyboard does when a suggestion is tapped: the typed
    /// prefix is replaced by the word and a space, and the model is told.
    @MainActor
    private func pick(_ word: String, in model: KeyboardModel, proxy: MockTextDocumentProxy) {
        let previous = model.previousWord(proxy: proxy)
        for _ in 0..<model.wordPrefix(proxy: proxy).count { proxy.deleteBackward() }
        proxy.insertText(word + " ")
        model.recordPickedSuggestion(word, previous: previous, insertedSpace: true)
        model.updateSuggestions(proxy: proxy)
    }

    private func scalars(_ text: String) -> [UInt32] { text.unicodeScalars.map(\.value) }

    // MARK: - Rows

    @MainActor
    func testKeyboardShowsThreeLetterRowsAndTheBottomRow() {
        let model = KeyboardModel()
        let rows = model.rows(needsGlobe: true)
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows[0].count, 11)
        XCTAssertEqual(rows[1].count, 11)
        XCTAssertEqual(rows[2].count, 11)   // shift, nine letters, backspace
        XCTAssertEqual(rows[0][8], .character("ъ"))
        XCTAssertEqual(rows[1][1], .character("\u{04C0}"))
        XCTAssertEqual(rows[1][10], .character("э"))
        XCTAssertEqual(rows[3], [.numbers, .settings, .emoji, .globe, .space, .return])
        XCTAssertEqual(model.rows(needsGlobe: false)[3], [.numbers, .settings, .emoji, .space, .return])
        XCTAssertEqual(model.layoutStyle, .standard)
    }

    // MARK: - Keys and digraphs

    @MainActor
    func testEveryLetterKeyInsertsItsLetter() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        let letters = "йцукенгшъзхф\u{04C0}вапролджэячсмитьбю"
        for ch in letters { model.handleKey(.character(String(ch)), proxy: proxy) }
        XCTAssertEqual(proxy.before, letters)
        XCTAssertEqual(proxy.before.unicodeScalars.count, 31)
        XCTAssertTrue(Aghul.isAghulText(proxy.before))
    }

    /// The palochka key inserts U+04C0 whatever the shift state: the letter
    /// is caseless, and the lookup form U+04CF never reaches the text.
    @MainActor
    func testPalochkaKeyInsertsU04C0() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        model.handleKey(.character("\u{04C0}"), proxy: proxy)
        XCTAssertEqual(scalars(proxy.before), [0x04C0])
        model.shiftState = .once
        model.handleKey(.character("\u{04C0}"), proxy: proxy)
        model.shiftState = .capsLock
        model.handleKey(.character("\u{04C0}"), proxy: proxy)
        XCTAssertEqual(scalars(proxy.before), [0x04C0, 0x04C0, 0x04C0])
        XCTAssertFalse(proxy.before.contains("\u{04CF}"))
        XCTAssertFalse(proxy.before.contains("I"))
        // Even a key that carried the lookup form would insert the visible one
        model.shiftState = .off
        model.handleKey(.character("\u{04CF}"), proxy: proxy)
        XCTAssertEqual(scalars(proxy.before).last, 0x04C0)
        model.shiftState = .off
    }

    /// The fifteen two-character letters and the four doubled ones, typed key by key.
    @MainActor
    func testDigraphsTypedKeyByKey() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        let text = (Aghul.digraphs + Aghul.doubled).joined(separator: " ")
        type(text, into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, text)
        XCTAssertEqual(scalars("кӀ"), [0x043A, 0x04C0])
        XCTAssertTrue(Aghul.isAghulText(proxy.before.replacingOccurrences(of: " ", with: "")))
    }

    /// A long-press option inserts the complete digraph; the result is the
    /// same string as typing its two keys.
    @MainActor
    func testLongPressOptionsInsertWholeDigraphs() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        let spec = KeyboardDefinition.current.layout.spec(for: .standard)
        var options: [String] = []
        for key in ["г", "д", "к", "п", "т", "у", "х", "ц", "ч", "е", "ш", "\u{04C0}"] {
            options += spec.callouts[key]!
        }
        XCTAssertEqual(options, ["гъ", "гь", "гӀ", "дж", "кь", "кӀ", "къ", "пӀ", "тӀ", "уь", "хь", "хъ", "хӀ", "цӀ", "чӀ",
                                 "ё", "щ", "ы"])
        for option in options { model.handleKey(.character(option), proxy: proxy) }
        XCTAssertEqual(proxy.before, "гъгьгӀджкькӀкъпӀтӀуьхьхъхӀцӀчӀёщы")
        XCTAssertEqual(proxy.before.unicodeScalars.count, 33)
        XCTAssertTrue(Aghul.isAghulText(proxy.before))
        XCTAssertFalse(proxy.before.contains("\u{04CF}"))

        let typed = MockTextDocumentProxy()
        for ch in "гъгьгӀджкькӀкъпӀтӀуьхьхъхӀцӀчӀ" { model.handleKey(.character(String(ch)), proxy: typed) }
        XCTAssertTrue(proxy.before.hasPrefix(typed.before))
        XCTAssertEqual(Array(typed.before.unicodeScalars), Array(proxy.before.unicodeScalars.prefix(30)))
    }

    /// Shift capitalizes the first letter of a digraph («КӀ», «Хъ», «Уь»),
    /// Caps Lock all of it («КӀ», «ХЪ», «УЬ»), for long-press options and
    /// plain keys alike. The palochka keeps its one form.
    @MainActor
    func testShiftAndCapsLockOnDigraphs() {
        let model = KeyboardModel()
        let titleCase = ["гъ": "Гъ", "гь": "Гь", "гӀ": "ГӀ", "дж": "Дж", "къ": "Къ", "кь": "Кь", "кӀ": "КӀ",
                         "пӀ": "ПӀ", "тӀ": "ТӀ", "уь": "Уь", "хъ": "Хъ", "хь": "Хь", "хӀ": "ХӀ", "цӀ": "ЦӀ",
                         "чӀ": "ЧӀ", "ё": "Ё", "щ": "Щ", "ы": "Ы"]
        let upperCase = ["гъ": "ГЪ", "гь": "ГЬ", "гӀ": "ГӀ", "дж": "ДЖ", "къ": "КЪ", "кь": "КЬ", "кӀ": "КӀ",
                         "пӀ": "ПӀ", "тӀ": "ТӀ", "уь": "УЬ", "хъ": "ХЪ", "хь": "ХЬ", "хӀ": "ХӀ", "цӀ": "ЦӀ",
                         "чӀ": "ЧӀ", "ё": "Ё", "щ": "Щ", "ы": "Ы"]
        XCTAssertEqual(titleCase.count, 18)
        for (option, expected) in titleCase {
            let proxy = MockTextDocumentProxy()
            model.shiftState = .once
            model.handleKey(.character(option), proxy: proxy)
            XCTAssertEqual(proxy.before, expected)
            XCTAssertEqual(model.shiftState, .off)
            XCTAssertFalse(proxy.before.contains("\u{04CF}"), expected)
            // The key label previews exactly what a tap inserts
            XCTAssertEqual(KeyboardLayout.label(for: .character(option), shifted: true, capsLock: false), expected)
        }
        for (option, expected) in upperCase {
            let proxy = MockTextDocumentProxy()
            model.shiftState = .capsLock
            model.handleKey(.character(option), proxy: proxy)
            XCTAssertEqual(proxy.before, expected)
            XCTAssertEqual(model.shiftState, .capsLock)
            XCTAssertFalse(proxy.before.contains("\u{04CF}"), expected)
            XCTAssertEqual(KeyboardLayout.label(for: .character(option), shifted: true, capsLock: true), expected)
        }
        // Key by key: Shift, ч, Ӏ, а, л → «ЧӀал»; Caps Lock → «ЧӀАЛ»
        let proxy = MockTextDocumentProxy()
        model.shiftState = .once
        type("чӀал", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "ЧӀал")
        proxy.before = ""
        model.shiftState = .capsLock
        type("чӀал", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "ЧӀАЛ")
        XCTAssertEqual(scalars(proxy.before), [0x0427, 0x04C0, 0x0410, 0x041B])
        model.shiftState = .off
    }

    @MainActor
    func testSentenceStartShiftsAndSpaceBehaviour() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        XCTAssertEqual(model.shiftState, .once)   // new field: auto-capitalized
        type("кӀилди", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "КӀилди")
        model.handleKey(.space, proxy: proxy)
        XCTAssertEqual(proxy.before, "КӀилди ")
        XCTAssertEqual(model.composedWord, "")
        // A long-press digraph at the start of a sentence is title case
        let fresh = MockTextDocumentProxy()
        let again = KeyboardModel()
        again.handleKey(.character("хь"), proxy: fresh)
        type("уная", into: again, proxy: fresh)
        XCTAssertEqual(fresh.before, "Хьуная")
    }

    /// The palochka as a letter of its own at the start of a sentence: the
    /// key inserts «Ӏ», which has one form, and the automatic capital is
    /// spent on it, as the Aghul books print the name («Ӏиса», not «ӀИса»).
    @MainActor
    func testPalochkaAtTheStartOfASentence() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        XCTAssertEqual(model.shiftState, .once)
        model.handleKey(.character("\u{04C0}"), proxy: proxy)
        XCTAssertEqual(model.shiftState, .off)
        type("иса", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "Ӏиса")
        XCTAssertEqual(scalars(proxy.before), [0x04C0, 0x0438, 0x0441, 0x0430])
        // In the middle of a sentence the same keys give the same word
        let middle = MockTextDocumentProxy(before: "пуная ")
        let again = KeyboardModel()
        again.shiftState = .off
        again.syncComposedWord(proxy: middle)
        type("Ӏиса", into: again, proxy: middle)
        XCTAssertEqual(middle.before, "пуная Ӏиса")
    }

    /// A word that begins with the letter «Ӏ» is learned and suggested like
    /// any other, with the palochka first and nothing else capitalized;
    /// Caps Lock raises the other letters.
    @MainActor
    func testWordsBeginningWithThePalochkaAreLearnedAndSuggested() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("Ӏисайи Ӏу ", into: model, proxy: proxy)
        // «Ӏу» (two) is the palochka and one more letter: a word of two letters
        XCTAssertEqual(model.savedWords().sorted(), ["Ӏисайи", "Ӏу"])
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertTrue(store.isRecognized("\u{04CF}у"))
        XCTAssertTrue(store.isRecognized("Iу"))                  // Latin I from another keyboard
        XCTAssertEqual(store.topWords(limit: 5).sorted(), ["\u{04CF}исайи", "\u{04CF}у"])
        // Mid-sentence
        type("Ӏи", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["Ӏи", "Ӏисайи"])
        // At the start of a sentence
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .once
        type("Ӏис", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "Ӏис")
        XCTAssertTrue(model.suggestions.contains("Ӏисайи"), "\(model.suggestions)")
        XCTAssertFalse(model.suggestions.joined().contains("\u{04CF}"))
        // Caps Lock
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .capsLock
        type("Ӏис", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "ӀИС")
        XCTAssertTrue(model.suggestions.contains("ӀИСАЙИ"), "\(model.suggestions)")
        model.shiftState = .off
    }

    // MARK: - Learning

    /// Typed with the keyboard's Ӏ, stored under the lookup form, shown
    /// again with Ӏ.
    @MainActor
    func testTypedWordIsLearnedCanonicallyAndSuggestedVisibly() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("кӀилди ", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "кӀилди ")
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertTrue(store.isRecognized("к\u{04CF}илди"))
        XCTAssertTrue(store.isRecognized("кӀилди"))
        XCTAssertTrue(store.isRecognized("КӀИЛДИ"))
        XCTAssertTrue(store.isRecognized("кIилди"))           // Latin I from another keyboard
        XCTAssertEqual(store.topWords(limit: 5), ["к\u{04CF}илди"])
        // Suggested back with the visible palochka while typing its prefix.
        // The bar leads with the typed prefix as a quoted literal (it is not
        // a word of its own), the learned word follows.
        type("кӀи", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["кӀи", "кӀилди"])
        XCTAssertFalse(model.suggestions.joined().contains("\u{04CF}"))
        XCTAssertTrue(model.isLearnedSuggestion("кӀилди"))
        XCTAssertEqual(model.savedWords(), ["кӀилди"])
    }

    /// A capitalized prefix capitalizes the suggestion's first letter only:
    /// «КӀ…» is a title-case digraph, not an all-caps prefix.
    @MainActor
    func testSuggestionFollowsTheCaseOfADigraphPrefix() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("кӀилди хьуная ", into: model, proxy: proxy)
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .once
        type("кӀ", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "КӀ")
        XCTAssertTrue(model.suggestions.contains("КӀилди"), "\(model.suggestions)")
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .once
        type("хьу", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "Хьу")
        XCTAssertTrue(model.suggestions.contains("Хьуная"), "\(model.suggestions)")
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .capsLock
        type("кӀи", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "КӀИ")
        XCTAssertTrue(model.suggestions.contains("КӀИЛДИ"), "\(model.suggestions)")
        model.shiftState = .off
    }

    /// Tapping a suggestion replaces the prefix with the whole word, with
    /// its digraphs intact, and adds the space.
    @MainActor
    func testAcceptedSuggestionInsertsTheWholeWord() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("гӀучӀуна ", into: model, proxy: proxy)
        type("гӀу", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["гӀу", "гӀучӀуна"])
        pick("гӀучӀуна", in: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "гӀучӀуна гӀучӀуна ")
        XCTAssertEqual(scalars(String(proxy.before.suffix(9))),
                       [0x0433, 0x04C0, 0x0443, 0x0447, 0x04C0, 0x0443, 0x043D, 0x0430, 0x0020])
        XCTAssertEqual(model.composedWord, "")
        // The pick itself counts as a stronger use than typing
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertTrue(store.isRecognized("гӀучӀуна"))
        // Sentence punctuation right after a picked word swallows the
        // automatic space
        model.handleKey(.character("."), proxy: proxy)
        XCTAssertEqual(proxy.before, "гӀучӀуна гӀучӀуна.")
    }

    @MainActor
    func testLearnedWordsSurviveANewModel() {
        do {
            let model = KeyboardModel()
            let proxy = MockTextDocumentProxy()
            model.shiftState = .off
            type("хӀавел гӀучӀуна ", into: model, proxy: proxy)
        }
        // A new keyboard controller (new model, same container)
        let again = KeyboardModel()
        let proxy = MockTextDocumentProxy(before: "хӀавел ")
        again.shiftState = .off
        again.syncComposedWord(proxy: proxy)
        XCTAssertEqual(again.savedWords().sorted(), ["гӀучӀуна", "хӀавел"])
        type("гӀу", into: again, proxy: proxy)
        XCTAssertEqual(again.suggestions, ["гӀу", "гӀучӀуна"])
    }

    @MainActor
    func testPersonalBigramPredictsTheNextWord() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        // A pair seen twice is confident enough to predict (minPairUses)
        type("агъул чӀал ", into: model, proxy: proxy)
        type("агъул чӀал ", into: model, proxy: proxy)
        // After the first word and a space, its learned follower leads the bar
        type("агъул ", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions.first, "чӀал")
    }

    @MainActor
    func testDeletingALearnedWordRemovesIt() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("кӀилди хьуная ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords().sorted(), ["кӀилди", "хьуная"])
        // The list shows Ӏ; deleting by that visible form reaches the row
        model.deleteLearnedWord("кӀилди", proxy: proxy)
        XCTAssertEqual(model.savedWords(), ["хьуная"])
        XCTAssertFalse(try XCTUnwrap(LearnedWords()).isRecognized("кӀилди"))
        model.resetLearnedWords(proxy: proxy)
        XCTAssertEqual(model.savedWords(), [])
        XCTAssertFalse(try XCTUnwrap(LearnedWords()).isRecognized("хьуная"))
    }

    /// A lone letter is not a word, and «ъ» and «ь» only extend the letter
    /// before them («хъ», «гь», «уь» are one letter each); the store
    /// refuses them. The palochka alone is one letter too.
    @MainActor
    func testSingleLettersAndLoneDigraphsAreNotLearned() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("хъ гь уь а \u{04C0} ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), [])
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertFalse(store.isRecognized("хъ"))
        XCTAssertFalse(store.isRecognized("\u{04C0}"))
    }

    // MARK: - Settings

    @MainActor
    func testSettingsPersistAcrossModels() {
        UserDefaults.standard.removeObject(forKey: "set_learnSpeed")   // a fresh install
        let model = KeyboardModel()
        XCTAssertEqual(model.settings.learnSpeed, .normal)
        XCTAssertEqual(model.settings.theme, .system)
        model.updateSettings {
            $0.theme = .dark
            $0.learnSpeed = .conservative
            $0.calloutDelay = .long
            $0.nextWordSuggestions = false
        }
        let again = KeyboardModel()
        XCTAssertEqual(again.settings.theme, .dark)
        XCTAssertEqual(again.settings.learnSpeed, .conservative)
        XCTAssertEqual(again.settings.calloutDelay, .long)
        XCTAssertFalse(again.settings.nextWordSuggestions)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "set_theme"), "dark")
        XCTAssertEqual(model.layoutStyle, .standard)
    }

    // MARK: - Learning speed

    /// A fresh install has no stored learning speed and follows General
    /// Keyboard's default, Normal: a word is suggested after three uses.
    @MainActor
    func testFreshInstallLearnsAWordAfterThreeUses() {
        UserDefaults.standard.removeObject(forKey: "set_learnSpeed")
        let model = KeyboardModel()
        XCTAssertEqual(model.settings.learnSpeed, .normal)
        XCTAssertEqual(model.settings.learnSpeed.minUses, 3)
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("кӀилди ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), [], "1 of 3 uses")
        type("кӀилди ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), [], "2 of 3 uses")
        type("кӀилди ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), ["кӀилди"])
        type("кӀи", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["кӀи", "кӀилди"])
        // Following the default stores nothing
        XCTAssertNil(UserDefaults.standard.object(forKey: "set_learnSpeed"))
    }

    /// A learning speed the user saved is kept: Fast stays Fast and Slow
    /// stays Slow, and words learned earlier are neither deleted nor reset.
    @MainActor
    func testSavedLearningSpeedAndLearnedWordsAreKept() throws {
        for (raw, speed) in [("fast", KeyboardSettings.LearnSpeed.fast), ("conservative", .conservative)] {
            UserDefaults.standard.set(raw, forKey: "set_learnSpeed")
            XCTAssertEqual(KeyboardModel().settings.learnSpeed, speed, raw)
            XCTAssertEqual(UserDefaults.standard.string(forKey: "set_learnSpeed"), raw)
        }
        // A word used once before the default was Normal, no stored choice
        UserDefaults.standard.removeObject(forKey: "set_learnSpeed")
        try XCTUnwrap(LearnedWords()).learn("кӀилди", previous: nil, picked: false)
        let model = KeyboardModel()
        XCTAssertEqual(model.savedWords(), [])
        XCTAssertTrue(try XCTUnwrap(LearnedWords()).isRecognized("кӀилди"), "the row and its count are still stored")
        model.updateSettings { $0.learnSpeed = .fast }
        XCTAssertEqual(model.savedWords(), ["кӀилди"])
    }
}
