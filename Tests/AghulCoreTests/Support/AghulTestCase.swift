//
//  AghulTestCase.swift
//  AghulCoreTests
//
//  Base class for every test that touches the engine: installs the
//  Aghul definition before the engine's statics capture it, exactly as
//  the extension's principal class does. Also the repository paths the
//  tests read (the shipped artifacts, the pinned upstream files, the
//  project).
//

import XCTest
import UIKit
@testable import AghulCore
@testable import GeneralKeyboard

class AghulTestCase: XCTestCase {
    override class func setUp() {
        super.setUp()
        KeyboardDefinition.install(AghulDefinition.definition)
    }
}

enum RepoPaths {
    /// The repository root, from this file's location
    /// (Tests/AghulCoreTests/Support/AghulTestCase.swift).
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Support
        .deletingLastPathComponent()   // AghulCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repository root

    static let extensionFolder = root.appendingPathComponent("AghulKeyboard/AghulKeyboardExtension")
    static let wordsArtifact = extensionFolder.appendingPathComponent("aghul_words.sqlite")
    static let bigramsArtifact = extensionFolder.appendingPathComponent("aghul_bigrams.sqlite")
    static let upstream = root.appendingPathComponent("Tests/AghulCoreTests/Fixtures/agisight")
    static let project = root.appendingPathComponent("AghulKeyboard/AghulKeyboard.xcodeproj/project.pbxproj")

    static func text(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
}

/// The palochka in its two roles and the two-character letters of the alphabet.
enum Aghul {
    /// Ӏ U+04C0: what keys, suggestions and every string show and insert.
    static let visible: Character = "\u{04C0}"
    /// ӏ U+04CF: the lookup form inside the artifacts and the learned store.
    static let lookup: Character = "\u{04CF}"

    /// The fifteen two-character letters offered on a long press, written
    /// as the keyboard types them.
    static let digraphs = ["гъ", "гь", "г\u{04C0}", "дж", "къ", "кь", "к\u{04C0}", "п\u{04C0}", "т\u{04C0}", "уь",
                           "хъ", "хь", "х\u{04C0}", "ц\u{04C0}", "ч\u{04C0}"]
    /// The four doubled letters of the alphabet, typed by tapping the key twice.
    static let doubled = ["кк", "пп", "тт", "чч"]

    /// Only Cyrillic letters of the Russian alphabet and the visible palochka.
    static func isAghulText(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy {
            (0x0410...0x044F).contains($0.value) || $0.value == 0x0401 || $0.value == 0x0451 || $0.value == 0x04C0
        }
    }
}

/// A minimal host text field: the context before the cursor is all the
/// suggestion and capitalization logic reads (same as General Keyboard's
/// test double).
final class MockTextDocumentProxy: NSObject, UITextDocumentProxy {
    var before: String
    init(before: String = "") { self.before = before }

    var documentContextBeforeInput: String? { before }
    var documentContextAfterInput: String? { nil }
    var selectedText: String? { nil }
    var documentInputMode: UITextInputMode? { nil }
    var documentIdentifier: UUID { UUID() }
    var hasText: Bool { !before.isEmpty }
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var returnKeyType: UIReturnKeyType = .default

    func adjustTextPosition(byCharacterOffset offset: Int) {}
    func setMarkedText(_ markedText: String, selectedRange: NSRange) {}
    func unmarkText() {}
    func insertText(_ text: String) { before += text }
    func deleteBackward() { if !before.isEmpty { before.removeLast() } }
}
