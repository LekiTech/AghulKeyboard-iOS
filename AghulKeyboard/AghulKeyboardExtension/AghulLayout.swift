//
//  AghulLayout.swift
//  AghulKeyboardExtension
//
//  The LekiTech Aghul layout (proposed; not an Apple or otherwise official
//  layout). It is the Russian iOS keyboard with two keys changed: the hard
//  sign «ъ» takes the place of «щ», and the palochka «Ӏ» takes the place of
//  «ы». «щ» moves under a long press on «ш», «ы» under «Ӏ».
//
//  Why: in Aghul text the palochka is 2.7–3.2 % of all characters (19 per
//  100 words: «кӀ», «хӀ», «гӀ», «тӀ», «чӀ», «цӀ», and the letter «Ӏ» of
//  «Ӏу», «Ӏуьмур», «яӀар») and «ъ» 2.3–2.6 % (14 per 100 words: «гъ», «хъ»,
//  «къ», the ending -ъ of «хулаъ»), while «щ» and «ы» are 0.02 % and
//  0.07 % of web text and do not occur in the Gospel of Luke at all. On
//  the Russian layout «Ӏ» and «ъ» need a long press, which the model puts
//  at 33 long presses per 100 words; here it is none in Luke and about
//  0.5 in web text.
//
//  It is the arrangement of the Dargwa and Tabasaran keyboards. Unlike
//  Lak, «э» keeps its key: Aghul writes it at the start of native words
//  («эесси», «экьуна», «эв»), 1.1 per 100 words.
//  The numbers, the alternatives that were compared and the open questions
//  are in docs/LAYOUT.md, computed by scripts/analyze_layout.py.
//
//  No community Aghul layout exists: Agisight/ios-system-keyboard has no
//  layout/agx, and Agisight/rf-keyboard-corpora has an empty layout stub
//  and two long-press mappings for the Russian keyboard
//  (data/agx/Ali_Kuzhuget/mapping at commit cd7a94e), which the digraph
//  callouts below follow except where noted.
//
//  The two-character letters of the alphabet are typed with the plain keys
//  (г + ъ, к + Ӏ, у + ь …) and are also offered as long-press options that
//  insert both characters at once. Rows are written once, in lowercase;
//  the engine derives the shift layer (first letter: «кӀ» → «КӀ», «гъ» →
//  «Гъ») and Caps Lock (all letters: «ГЪ»).
//
//  Product data: the engine reads it only through
//  `KeyboardDefinition.current.layout` (see AghulDefinition.swift).
//

import Foundation
import GeneralKeyboard

extension LayoutStyle {
    /// The one Aghul layout. Persisted raw value; never rename.
    static let standard = LayoutStyle(rawValue: "standard")
}

enum AghulLayout {

    /// Ӏ U+04C0 CYRILLIC LETTER PALOCHKA: what the key shows and inserts.
    /// Never Latin I, the digit 1 or lowercase l.
    static let palochka = "\u{04C0}"

    static let capabilities = LayoutCapabilities(
        styles: [standard],
        defaultStyle: .standard,
        // One style: the engine hides the selector and the quick menu.
        showsStyleSelector: false,
        persistenceKey: "layoutStyle",
        quickSwitchOnSettingsLongPress: false,
        // iPhone portrait on Apple's native keyboard grid (pixel-snapped
        // cells, native bottom-row proportions, native panel height), as
        // approved for Lezgi, Dargwa, Kumyk, Tabasaran and Lak
        gridModel: .nativeCells
    )

    static let standard = LayoutStyleSpec(
        id: .standard,
        letterRows: letterRows,
        numberRows: numberRows,
        symbolRows: symbolRows,
        callouts: callouts,
        metrics: metrics,
        settingsTitle: "Стандартная",
        settingsSubtitle: "Русская раскладка, ъ на месте щ, Ӏ на месте ы"
    )

    /// Three letter rows and the geometry the sibling keyboards ship with.
    static let metrics = KeyboardLayout.Metrics(totalHeight: 250, keyHeight: 43, rowSpacing: 11,
                                                emojiRows: 5, emojiCellHeight: 33)

    // MARK: - Letter rows

    static let letterRows: [[KeyCap]] = [
        ["й","ц","у","к","е","н","г","ш","ъ","з","х"].map { .character($0) },        // 11 keys, ъ on щ's key
        ["ф",palochka,"в","а","п","р","о","л","д","ж","э"].map { .character($0) },   // 11 keys, Ӏ on ы's key
        [.shift]
            + ["я","ч","с","м","и","т","ь","б","ю"].map { KeyCap.character($0) }     // 9 keys, as Russian
            + [.backspace],
    ]

    // MARK: - Number page (the standard Russian iOS set)

    static let numberRows: [[KeyCap]] = [
        ["1","2","3","4","5","6","7","8","9","0"].map { .character($0) },
        ["-","/",":",";","(",")","₽","&","@","\""].map { .character($0) },
        [.symbols] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Symbol page (the standard Russian iOS set)

    static let symbolRows: [[KeyCap]] = [
        ["[","]","{","}","#","%","^","*","+","="].map { .character($0) },
        ["_","\\","|","~","<",">","$","€","¥","•"].map { .character($0) },
        [.numbers] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Long-press callouts
    // Keys are lowercase; the popup puts the base key first and the shift
    // state is applied to every option. An option is inserted as a whole
    // string («кӀ» = к + palochka U+04C0, two Cyrillic characters).

    /// Fifteen of the nineteen two-character letters of the Aghul alphabet
    /// (Гъ Гь ГӀ Дж Къ Кь КӀ ПӀ ТӀ Уь Хъ Хь ХӀ ЦӀ ЧӀ) under their first
    /// letter. Where a key has several, they are in the order of their
    /// frequency in web text, the larger sample (Agisight/rf-keyboard-corpora,
    /// agx_monocorpus_freq.csv: гъ 0.95 % of letters, гь 0.89 %, гӀ 0.49 %;
    /// кь 1.22 %, кӀ 0.48 %, къ 0.23 %; хь 1.14 %, хъ 0.86 %, хӀ 0.73 %).
    /// The Gospel of Luke gives the same order on «к» and «х» and puts «гь»
    /// first on «г» («Аллагь»).
    ///
    /// The other four letters are doubled consonants (Кк Пп Тт Чч) and are
    /// typed by tapping the key twice, which is quicker than any long
    /// press; Agisight's mapping offers them under a long press and puts
    /// «дж» on «ж» (docs/LAYOUT.md, open questions).
    static let digraphCallouts: [String: [String]] = [
        "г": ["гъ", "гь", "г" + palochka],
        "д": ["дж"],
        "к": ["кь", "к" + palochka, "къ"],
        "п": ["п" + palochka],
        "т": ["т" + palochka],
        "у": ["уь"],
        "х": ["хь", "хъ", "х" + palochka],
        "ц": ["ц" + palochka],
        "ч": ["ч" + palochka],
    ]

    /// The three Russian letters without a key, each where a Russian typist
    /// looks for it: ё under е and щ under ш as on the Russian keyboard, ы
    /// on the key that took its place. Aghul uses them in loans only.
    static let letterCallouts: [String: [String]] = [
        "е": ["ё"],
        "ш": ["щ"],
        palochka: ["ы"],
    ]

    /// The symbol alternates of the Russian iOS keyboard (as the sibling
    /// keyboards; the quote alternates sit on this layout's ' and " keys).
    static let symbolCallouts: [String: [String]] = [
        "0": ["°"],
        "₽": ["$", "€", "£", "¥", "￦"],
        "#": ["№"],
        ".": ["…"],
        "%": ["‰", "∞"],
        "=": ["≠", "≈"],
        "-": ["•", "–", "—"],
        "/": ["\\"],
        "&": ["§"],
        "?": ["¿"],
        "!": ["¡"],
        "'": ["’", "‘", "`"],
        "\"": ["”", "“", "„", "»", "«"],
    ]

    static let callouts: [String: [String]] = digraphCallouts
        .merging(letterCallouts) { first, _ in first }
        .merging(symbolCallouts) { first, _ in first }
}
