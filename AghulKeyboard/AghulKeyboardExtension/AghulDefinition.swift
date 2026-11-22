//
//  AghulDefinition.swift
//  AghulKeyboardExtension
//
//  The Aghul keyboard as a KeyboardDefinition: everything Aghul-specific
//  the General Keyboard engine uses, assembled in one value. The layout
//  lives in AghulLayout.swift, strings and key names in AghulStrings.swift.
//

import Foundation
import GeneralKeyboard

enum AghulDefinition {

    /// Aghul Cyrillic, version 1: the canonical form of the bundled
    /// dictionary (scripts/build_dictionary.py mirrors it) and of learned
    /// words.
    ///
    /// It is the built-in Dagestanian Cyrillic profile with one difference:
    /// the palochka is not a digraph tail. In the Aghul alphabet «Ӏ» is
    /// also a letter of its own, a consonant written at the start, in the
    /// middle and at the end of a word («Ӏу», «Ӏуьмур», «яӀар», «лиӀ»). The
    /// built-in profile counts it as part of the letter before it, so «Ӏу»
    /// ("two", one of the most frequent words of the language) would be a
    /// one-letter token that the keyboard may neither store nor learn.
    /// Here «ъ» and «ь» alone extend the previous letter («гъ», «хь», «уь»
    /// are one letter each); «кӀ» counts as two.
    ///
    /// Everything else is the built-in rule set: the lookup palochka is ӏ
    /// U+04CF, and a Latin I, l or i, the Ukrainian І and the capital Ӏ
    /// inside a Cyrillic token are read as it.
    ///
    /// Identity is (id, version). Changing a rule means a new version, a
    /// dictionary rebuild and a sweep of learned data.
    static let normalization = NormalizationProfile(
        id: "aghul-cyrillic",
        version: 1,
        repairScripts: NormalizationProfile.dagestanianCyrillicV1.repairScripts,
        palochka: NormalizationProfile.dagestanianCyrillicV1.palochka,
        palochkaLookalikes: NormalizationProfile.dagestanianCyrillicV1.palochkaLookalikes,
        homoglyphs: NormalizationProfile.dagestanianCyrillicV1.homoglyphs,
        rejectsASCIILetters: true,
        digraphTails: ["\u{044C}", "\u{044A}"]   // ь ъ
    )

    static let definition = KeyboardDefinition(
        // Stable identity: the extension's App Store bundle identifier.
        // Never reused for a different definition.
        id: "org.lekitech.aghulkeyboard.AghulKeyboardExtension",
        data: LanguageData(
            appGroupID: AghulIdentity.appGroupID,
            // AghulKeyboardExtension/aghul_words.sqlite and
            // aghul_bigrams.sqlite, built by scripts/build_dictionary.py
            wordsArtifact: "aghul_words",
            bigramsArtifact: "aghul_bigrams",
            diagnosticsSubsystem: "AghulKeyboardExtension"
        ),
        layout: AghulLayout.capabilities,
        keys: AghulStrings.keys,
        text: TextConventions(
            // Everything the user sees and types carries the palochka
            // Ӏ (U+04C0); lookup keys and stored rows keep ӏ (U+04CF).
            visiblePalochka: "\u{04C0}",
            // Ӏ is category Lu but caseless by convention: «КӀ» is a
            // capitalized digraph, not an ALL-CAPS prefix.
            caseNeutral: ["\u{04C0}", "\u{04CF}"]
        ),
        // Aghul spelling has no apostrophe or other mark inside a word, so
        // the engine's default word separators apply.
        normalization: normalization,
        strings: AghulStrings.strings,
        emojiCategoryTitles: AghulStrings.emojiCategoryTitles
    )
}
