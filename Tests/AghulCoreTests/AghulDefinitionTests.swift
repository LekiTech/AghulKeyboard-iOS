//
//  AghulDefinitionTests.swift
//  AghulCoreTests
//
//  The Aghul KeyboardDefinition: its own identity (never another
//  product's), the persisted contract, the Aghul Cyrillic profile (the
//  Dagestanian rules with the palochka counted as a letter) and the
//  palochka convention (Ӏ U+04C0 shown and typed, ӏ U+04CF as the lookup
//  key), the engine's default word separators, and the project's
//  two-target, two-identity setup (Debug for the developer's team, Release
//  for distribution).
//

import XCTest
import UIKit
@testable import AghulCore
@testable import GeneralKeyboard

final class AghulDefinitionTests: AghulTestCase {

    private var d: KeyboardDefinition { KeyboardDefinition.current }

    func testIdentityAndArtifacts() {
        XCTAssertEqual(d.validationErrors(), [])
        XCTAssertEqual(d.id, "org.lekitech.aghulkeyboard.AghulKeyboardExtension")
        XCTAssertEqual(AghulIdentity.releaseAppGroupID, "group.org.lekitech.aghulkeyboard")
        XCTAssertEqual(AghulIdentity.debugAppGroupID, "group.org.lekitech.aghulkeyboard.dev")
        // Tests build in Debug
        XCTAssertEqual(d.data.appGroupID, AghulIdentity.debugAppGroupID)
        XCTAssertEqual(WordSuggestions.artifactName, "aghul_words")
        XCTAssertEqual(StaticBigrams.artifactName, "aghul_bigrams")
        XCTAssertEqual(d.data.diagnosticsSubsystem, "AghulKeyboardExtension")
    }

    func testNeverReusesAnotherProductsIdentity() {
        let taken = ["lezgi", "avar", "dargwa", "kumyk", "tabasaran", "lakkeyboard", "vadivian", "generalkeyboard",
                     "reference"]
        for value in [d.id, d.data.appGroupID, AghulIdentity.releaseAppGroupID,
                      d.data.wordsArtifact, d.data.bigramsArtifact] {
            for other in taken {
                XCTAssertFalse(value.lowercased().contains(other), "\(value) contains \(other)")
            }
        }
    }

    // MARK: - Normalization and the palochka

    /// Aghul has its own profile: the built-in Dagestanian Cyrillic rules
    /// in everything but the digraph tails. The palochka is a letter of the
    /// Aghul alphabet in its own right («Ӏу», «яӀар», «лиӀ»), so only «ь»
    /// and «ъ» extend the letter before them.
    func testUsesItsOwnProfileWithThePalochkaAsALetter() {
        let builtIn = NormalizationProfile.dagestanianCyrillicV1
        XCTAssertEqual(d.normalization, AghulDefinition.normalization)
        XCTAssertNotEqual(d.normalization, builtIn)
        XCTAssertEqual(d.normalization.id, "aghul-cyrillic")
        XCTAssertEqual(Normalization.version, 1)
        XCTAssertEqual(Normalization.palochka, Aghul.lookup)
        XCTAssertEqual(d.normalization.digraphTails, ["ь", "ъ"])
        XCTAssertEqual(builtIn.digraphTails.subtracting(d.normalization.digraphTails), [Aghul.lookup])
        XCTAssertEqual(d.normalization.repairScripts, builtIn.repairScripts)
        XCTAssertEqual(d.normalization.palochkaLookalikes, builtIn.palochkaLookalikes)
        XCTAssertEqual(d.normalization.homoglyphs, builtIn.homoglyphs)
        XCTAssertEqual(d.normalization.rejectsASCIILetters, builtIn.rejectsASCIILetters)
        XCTAssertEqual(d.text.visiblePalochka, Aghul.visible)
        XCTAssertEqual(d.text.caseNeutral, [Aghul.visible, Aghul.lookup])
    }

    /// One lookup key however the palochka was written: Ӏ U+04C0, ӏ U+04CF,
    /// or the Latin I, l and Ukrainian І that other keyboards and the
    /// AgulLang dictionary produce.
    func testCanonicalFormOfAghulWords() {
        XCTAssertEqual(Normalization.canonical("К\u{04C0}илди"), "к\u{04CF}илди")
        XCTAssertEqual(Normalization.canonical("кIилди"), "к\u{04CF}илди")
        XCTAssertEqual(Normalization.canonical("кlилди"), "к\u{04CF}илди")
        XCTAssertEqual(Normalization.canonical("к\u{0406}илди"), "к\u{04CF}илди")
        XCTAssertEqual(Normalization.canonical("  Г\u{04C0}УЧ\u{04C0}УНА\n"), "г\u{04CF}уч\u{04CF}уна")
        XCTAssertEqual(Normalization.canonical("Хьуная"), "хьуная")
        // The palochka as a letter of its own, however it was typed
        XCTAssertEqual(Normalization.canonical("\u{04C0}иса"), "\u{04CF}иса")
        XCTAssertEqual(Normalization.canonical("Iиса"), "\u{04CF}иса")
        XCTAssertEqual(Normalization.canonical("\u{04C0}у"), "\u{04CF}у")
        // NFC: «й» typed as и plus a combining breve
        XCTAssertEqual(Normalization.canonical("\u{04C0}исаи\u{0306}и"), "\u{04CF}исайи")
        // Latin twins inside a Cyrillic word are repaired (а, х here)
        XCTAssertEqual(Normalization.canonical("xaбар"), "хабар")
        // The digit 1 is not a palochka: such a token is refused, not repaired
        XCTAssertFalse(Normalization.isValidToken(Normalization.canonical("к1илди")))
        for word in ["к\u{04CF}илди", "\u{04CF}исайи", "\u{04CF}у", "я\u{04CF}", "хьуная", "ппара", "юрк\u{04CF}в",
                     "эесси", "дад-баб"] {
            XCTAssertTrue(Normalization.isCanonical(word), word)
            XCTAssertTrue(Normalization.isValidToken(word), word)
        }
        // What the user sees again carries U+04C0
        XCTAssertEqual(d.text.visibleForm("к\u{04CF}илди", canonicalPalochka: Normalization.palochka), "к\u{04C0}илди")
        XCTAssertEqual(d.text.visibleForm("\u{04CF}у", canonicalPalochka: Normalization.palochka), "\u{04C0}у")
    }

    /// «ъ» and «ь» extend the letter before them, so a lone «гъ» or «уь»
    /// is one letter and never learned as a word. The palochka counts as a
    /// letter: «Ӏу» is a word of two letters, «кӀ» two characters and two
    /// letters.
    func testLetterCount() {
        for digraph in ["гъ", "гь", "къ", "кь", "уь", "хъ", "хь"] {
            XCTAssertEqual(Normalization.letterCount(digraph), 1, digraph)
            XCTAssertFalse(Normalization.isValidToken(digraph), digraph)
        }
        XCTAssertEqual(Normalization.letterCount("\u{04CF}"), 1)
        XCTAssertFalse(Normalization.isValidToken("\u{04CF}"))
        XCTAssertEqual(Normalization.letterCount("\u{04CF}у"), 2)        // ӏ у
        XCTAssertTrue(Normalization.isValidToken("\u{04CF}у"))
        XCTAssertEqual(Normalization.letterCount("ли\u{04CF}"), 3)       // л и ӏ
        XCTAssertEqual(Normalization.letterCount("\u{04CF}уьмур"), 5)    // ӏ уь м у р
        XCTAssertEqual(Normalization.letterCount("хьуная"), 5)           // хь у н а я
        XCTAssertEqual(Normalization.letterCount("ттур"), 4)             // a doubled consonant is two characters
        XCTAssertEqual(Normalization.letterCount("ч\u{04CF}ал"), 4)      // ч ӏ а л
        XCTAssertTrue(Normalization.isValidToken("ц\u{04CF}а"))
    }

    // MARK: - Word separators

    /// Aghul spelling has no apostrophe or other mark inside a word, so the
    /// engine's default separators apply unchanged; the palochka and the
    /// signs are letters.
    func testWordSeparatorsAreTheEngineDefaults() {
        let separators = d.text.wordSeparators
        XCTAssertEqual(separators, TextConventions.defaultWordSeparators)
        for scalar in " \n.,!?;:\"'()[]{}—–-".unicodeScalars {
            XCTAssertTrue(separators.contains(scalar))
        }
        for scalar in "аяъьщ\u{04C0}\u{04CF}".unicodeScalars {
            XCTAssertFalse(separators.contains(scalar))
        }
    }

    // MARK: - Layout capabilities and strings

    func testLayoutCapabilities() {
        XCTAssertEqual(d.layout.styles.map(\.id.rawValue), ["standard"])
        XCTAssertEqual(d.layout.defaultStyle.rawValue, "standard")
        XCTAssertEqual(d.layout.persistenceKey, "layoutStyle")
        XCTAssertFalse(d.layout.showsSelector)
        XCTAssertFalse(d.layout.showsQuickSwitch)
        XCTAssertEqual(d.layout.gridModel, .nativeCells)
        XCTAssertEqual(d.layout.resolve(nil).rawValue, "standard")
        XCTAssertEqual(d.layout.resolve("classic").rawValue, "standard")
        XCTAssertEqual(d.layout.spec(for: .standard).bottomRowAfterSpace, [])
    }

    /// Everything the user reads or types carries Ӏ U+04C0, never the
    /// lookup form ӏ U+04CF and never a Latin I or l standing in for it.
    func testUserFacingTextUsesTheVisiblePalochka() {
        let s = d.strings
        var texts: [String] = [
            s.deleteWordQuestion("кӀилди"), s.no, s.delete, s.emojiRecents, s.back, s.close,
            s.settingsCaption, s.settingsTitle, s.pageInput, s.pageTheme, s.pageDictionary,
            s.pageAbout, s.sectionLayout, s.sectionSuggestions, s.sectionKeys, s.sectionLearning,
            s.sectionLongPress, s.sectionTheme, s.wordSuggestions, s.nextWordSuggestion,
            s.autoSpace, s.doubleSpacePeriod, s.spaceCursor, s.spaceCornerToggle,
            s.spaceCornerToggleSubtitle, s.learnFast, s.learnNormal, s.learnSlow, s.learnUses(3),
            s.calloutShort, s.calloutNormal, s.calloutLong, s.calloutDuration(0.3), s.themeSystem,
            s.themeLight, s.themeDark, s.learnedWordsCaption, s.noWordsYet, s.deleteAll,
            s.deleteAllQuestion, s.aboutInitial, s.aboutTitle, s.aboutByline("1.0.0"),
            d.keys.space, d.keys.spaceCornerLabel, d.keys.keyboardName, d.keys.lettersKey,
            d.keys.lettersKeyShifted, d.keys.emojiPageLettersKey,
        ]
        texts += d.keys.returnLabels.values
        texts += d.emojiCategoryTitles.values
        let spec = d.layout.spec(for: .standard)
        texts += [spec.settingsTitle, spec.settingsSubtitle]
        var letterTexts: [String] = []
        for row in spec.letterRows {
            for case .character(let c) in row { letterTexts.append(c) }
        }
        for (key, alternates) in spec.callouts where key.first!.isLetter { letterTexts += [key] + alternates }
        for text in texts + letterTexts {
            XCTAssertFalse(text.contains(Aghul.lookup), "\(text) shows the lookup palochka U+04CF")
        }
        // No Latin letter on a letter key or in a letter's long press
        for text in letterTexts {
            XCTAssertFalse(text.contains(where: { $0.isASCII && $0.isLetter }), "\(text) has a Latin letter")
        }
        XCTAssertEqual(d.keys.keyboardName, "Агъул ч\u{04C0}ал")
        XCTAssertEqual(d.keys.spaceCornerLabel, "АГЪУЛ")
        XCTAssertEqual(s.spaceCornerToggle, "«агъул» на пробеле")
        XCTAssertEqual(s.settingsCaption, "АГУЛЬСКАЯ КЛАВИАТУРА")
        XCTAssertEqual(s.aboutTitle, "Агульская клавиатура")
        XCTAssertEqual(s.aboutInitial, "А")
        XCTAssertEqual(s.sectionLongPress, "Долгое нажатие (к\u{04C0}, хь, ё…)")
        // The palochka key itself
        XCTAssertEqual(spec.letterRows[1][1], .character(String(Aghul.visible)))
    }

    /// Every two-letter long-press option that ends in «ъ» or «ь» is one
    /// letter for the engine (its tail is a digraph tail of the profile);
    /// one that ends in the palochka, and «дж», is two.
    func testLetterCountOfEveryTwoCharacterCallout() {
        var one = 0, two = 0
        for (_, alternates) in d.layout.spec(for: .standard).callouts {
            for alt in alternates where alt.count == 2 && alt.first!.isLetter {
                let canonical = Normalization.canonical(alt)
                if d.normalization.digraphTails.contains(canonical.last!) {
                    XCTAssertEqual(Normalization.letterCount(canonical), 1, alt)
                    one += 1
                } else {
                    XCTAssertTrue(canonical.last == Aghul.lookup || canonical == "дж", alt)
                    XCTAssertEqual(Normalization.letterCount(canonical), 2, alt)
                    two += 1
                }
            }
        }
        XCTAssertEqual(one, 7)    // гъ гь къ кь уь хъ хь
        XCTAssertEqual(two, 8)    // гӀ кӀ пӀ тӀ хӀ цӀ чӀ дж
    }

    func testRussianFallbackFormatting() {
        let s = d.strings
        XCTAssertEqual(s.learnUses(1), "1 раз")
        XCTAssertEqual(s.learnUses(3), "3 раза")
        XCTAssertEqual(s.learnUses(5), "5 раз")
        XCTAssertEqual(s.learnUses(12), "12 раз")
        XCTAssertEqual(s.learnUses(22), "22 раза")
        XCTAssertEqual(s.calloutDuration(0.2), "0,2 с")
        XCTAssertEqual(s.calloutDuration(0.45), "0,45 с")
        XCTAssertEqual(s.aboutByline("1.0.0"), "Версия 1.0.0 · LekiTech")
    }

    // MARK: - Project

    /// Two targets, no sticker or messenger targets; Debug signs with the
    /// developer's team under `.dev` identifiers, Release carries the App
    /// Store identifiers and no team (the distribution team adds its own).
    func testProjectTargetsAndSigning() throws {
        let pbx = try RepoPaths.text(RepoPaths.project)
        XCTAssertEqual(pbx.components(separatedBy: "isa = PBXNativeTarget;").count - 1, 2)
        XCTAssertEqual(pbx.components(separatedBy: "com.apple.product-type.application\"").count - 1, 1)
        XCTAssertEqual(pbx.components(separatedBy: "com.apple.product-type.app-extension\"").count - 1, 1)
        for banned in ["sticker", "Sticker", "messages", "telegram", "whatsapp", "instagram",
                       "Lezgi", "lezgi", "Avar", "avar", "Dargwa", "dargwa", "Kumyk", "kumyk",
                       "Tabasaran", "tabasaran", "LakKeyboard", "lakkeyboard", "vadivian"] {
            XCTAssertFalse(pbx.contains(banned), "project mentions \(banned)")
        }
        let bundleIDs = Set(pbx.matches(of: /PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/).map { String($0.1) })
        XCTAssertEqual(bundleIDs, [
            "org.lekitech.aghulkeyboard.dev", "org.lekitech.aghulkeyboard.dev.AghulKeyboardExtension",
            "org.lekitech.aghulkeyboard", "org.lekitech.aghulkeyboard.AghulKeyboardExtension",
        ])
        let groups = Set(pbx.matches(of: /AGHUL_APP_GROUP_ID = ([^;]+);/).map { String($0.1) })
        XCTAssertEqual(groups, [AghulIdentity.debugAppGroupID, AghulIdentity.releaseAppGroupID])
        let teams = pbx.matches(of: /\bDEVELOPMENT_TEAM = ([^;]+);/).map { String($0.1) }
        XCTAssertEqual(teams.sorted(), ["\"\"", "\"\"", "RC94H8KQYA", "RC94H8KQYA"])
        XCTAssertTrue(pbx.contains("relativePath = \"../../GeneralKeyboard-iOS\";"))

        for file in ["AghulKeyboard/AghulKeyboard/AghulKeyboard.entitlements",
                     "AghulKeyboard/AghulKeyboardExtension/AghulKeyboardExtension.entitlements"] {
            let plist = try RepoPaths.text(RepoPaths.root.appendingPathComponent(file))
            XCTAssertTrue(plist.contains("<string>$(AGHUL_APP_GROUP_ID)</string>"), file)
        }
        let info = try RepoPaths.text(RepoPaths.extensionFolder.appendingPathComponent("Info.plist"))
        XCTAssertTrue(info.contains("<string>agx</string>"))
        XCTAssertTrue(info.contains("<key>RequestsOpenAccess</key>\n\t\t\t<false/>"))
    }
}
