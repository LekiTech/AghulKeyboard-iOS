//
//  AghulStrings.swift
//  AghulKeyboardExtension
//
//  Every native string the keyboard draws, its key names and the emoji
//  section titles. Edit here, never in engine files.
//
//  Sources:
//  * The language name «Агъул чӀал» is the attested self-name: it is the
//    name the Russian and English Wikipedia articles, Glottolog and the
//    Institute of Linguistics (minlang.iling-ran.ru, "автолингвоним") give,
//    and the title of the draft spelling rules («Агъул чӀалан орфографин
//    къайдабурин свод»). The bundled dictionary has both words («агъул»,
//    «чӀал»).
//  * Everything else is TEMPORARY RUSSIAN TEXT: no verified Aghul
//    translation of the key names or of the settings panel exists yet, and
//    none is invented here. docs/LOCALIZATION.md lists every string for an
//    Aghul review.
//

import UIKit
import GeneralKeyboard

enum AghulStrings {

    static let strings = KeyboardStrings(
        deleteWordQuestion: { word in "Удалить «\(word)»?" },
        no: "Нет",
        delete: "Удалить",
        emojiRecents: "Недавние",
        back: "Назад",
        close: "Клавиатура",
        settingsCaption: "АГУЛЬСКАЯ КЛАВИАТУРА",
        settingsTitle: "Настройки",
        pageInput: "Ввод",
        pageTheme: "Тема",
        pageDictionary: "Словарь",
        pageAbout: "О клавиатуре",
        sectionLayout: "Раскладка",
        sectionSuggestions: "Подсказки",
        sectionKeys: "Клавиши",
        sectionLearning: "Обучение",
        sectionLongPress: "Долгое нажатие (кӀ, хь, ё…)",
        sectionTheme: "Тема",
        wordSuggestions: "Подсказки слов",
        nextWordSuggestion: "Подсказка следующего слова",
        autoSpace: "Пробел после подсказки",
        doubleSpacePeriod: "Два пробела — точка",
        spaceCursor: "Курсор пробелом",
        spaceCornerToggle: "«агъул» на пробеле",
        spaceCornerToggleSubtitle: String(localized: "Show «агъул» on the space bar"),
        learnFast: "Быстро",
        learnNormal: "Обычно",
        learnSlow: "Медленно",
        learnUses: { count in "\(count) \(russianTimes(count))" },
        calloutShort: "Короткая задержка",
        calloutNormal: "Обычная задержка",
        calloutLong: "Длинная задержка",
        // Decimal comma and the Cyrillic «с»: 0.2 → «0,2 с», 0.45 → «0,45 с».
        calloutDuration: { seconds in
            String(format: "%g", seconds).replacingOccurrences(of: ".", with: ",") + " с"
        },
        themeSystem: "Системная",
        themeLight: "Светлая",
        themeDark: "Тёмная",
        learnedWordsCaption: "выученные слова",
        noWordsYet: "Пока нет слов",
        deleteAll: "Удалить все выученные слова",
        deleteAllQuestion: "Удалить все выученные слова?",
        aboutInitial: "А",
        aboutTitle: "Агульская клавиатура",
        aboutByline: { version in "Версия \(version) · LekiTech" }
    )

    /// «раз», «раза» or «раз» after a number (1 раз, 3 раза, 5 раз).
    static func russianTimes(_ n: Int) -> String {
        let lastTwo = n % 100, last = n % 10
        if (11...14).contains(lastTwo) { return "раз" }
        if (2...4).contains(last) { return "раза" }
        return "раз"
    }

    static let keys = KeyLabels(
        // Temporary Russian, as on the Russian iOS keyboard
        space: "Пробел",
        // The self-name «агъул», like «ЛЕЗГ», «АВАР», «ДАРГ», «КЪУМ»,
        // «ТАБ» and «ЛАК»
        spaceCornerLabel: "АГЪУЛ",
        // The self-name of the language
        keyboardName: "Агъул чӀал",
        lettersKey: "АБВ",
        lettersKeyShifted: "АБВ",
        emojiPageLettersKey: "АБВ",
        // Temporary Russian, the labels of the Russian iOS keyboard. The
        // plain return key keeps the engine's ⏎ icon. The search label only
        // sizes the key; the engine always draws the magnifying glass.
        returnLabels: [
            .go: "Перейти",
            .send: "Отправить",
            .done: "Готово",
            .next: "Далее",
            .`continue`: "Продолжить",
            .join: "Подкл.",
            .route: "Маршрут",
            .search: "Найти",
            .emergencyCall: "SOS",
        ]
    )

    /// Emoji section titles by catalog id (temporary Russian text, as in
    /// the Russian iOS keyboard).
    static let emojiCategoryTitles: [String: String] = [
        "smileys": "Смайлики и люди",
        "nature": "Животные и природа",
        "food": "Еда и напитки",
        "activity": "Активность",
        "travel": "Путешествия и места",
        "objects": "Предметы",
        "symbols": "Символы",
        "flags": "Флаги",
    ]
}
