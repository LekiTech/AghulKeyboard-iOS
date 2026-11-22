# Naming, localization and strings for review

## The English name: Aghul

Both «Agul» and «Aghul» are in use. The app is named **Aghul**.

| Where | Spelling |
|---|---|
| ISO 639-3 (`agx`), IANA language subtag registry | Aghul |
| Glottolog (aghu1253), WALS, Wikidata, English Wikipedia (article «Aghul language») | Aghul; «Agul» as an alternate name |
| Unicode CLDR | no display name for `agx`; the likely-subtags entry is commented «Aghul» |
| Intercontinental Dictionary Series | Aghul |
| Institute for Bible Translation, the publisher of the Aghul books | Aghul (project page, Scripture app, the 2026 edition); its web address still says «agul» |
| Papers by the language's describers (Maisak, Merdanova, Ganenkov) | mostly «Agul», about 12 titles to 2; «Agul (also spelled Aghul)» on their project page |
| Agisight/rf-keyboard-corpora | «Aghul» in the layout stub, «Agul» in its README |
| Keyboards and locales elsewhere (Keyman, Gboard, App Store) | none exist |

Reasons: the standards a platform reads (ISO 639-3, IANA, and so CLDR if
it ever lists the language) and the reference works a user is likely to
search (Wikipedia, Glottolog) say «Aghul»; the publisher of the Aghul
books uses it; and it is the spelling that keeps the «гъ» of the
self-name «агъул». «Agul», the transliteration of Russian «агульский», is
the usual spelling in the descriptive literature and would be a defensible
choice as well. The identifiers are provisional until the first release,
so renaming is still possible (project, targets, bundle IDs, App Group,
artifact names).

In Russian the name is «Агульская клавиатура», as in every source.

## Names on the device

| Where | English and other languages | Russian |
|---|---|---|
| Home Screen (app `InfoPlist.xcstrings`, `CFBundleDisplayName` and `CFBundleName`) | Aghul | Агъул чӀал |
| Keyboard list and globe menu (extension `InfoPlist.xcstrings`) | Aghul | Агульский |
| Title on the app's screen | Aghul Keyboard | Агульская клавиатура |

English is the development language and the fallback for every language
other than Russian; the target's `INFOPLIST_KEY_CFBundleDisplayName`
(«Aghul») is only the unlocalized fallback. The Russian localization of
the app carries the language's own name, as approved for the sibling
keyboards (Авар мацӀ, Дарган мез, Къумукъ тил, Табасаран чӀал, Лакку маз).
«Агъул чӀал» is ten characters with its space, shorter than «Къумукъ тил»,
which fits every supported iPhone; it was not measured on a device.

## What is Aghul today

| Where | String | Source |
|---|---|---|
| Home Screen name (Russian), keyboard name (flashed on the space bar), app header | Агъул чӀал | the self-name of the language: English Wikipedia and Glottolog («агъул чӀал»), Russian Wikipedia, the Institute of Linguistics' site (as "автолингвоним"), the Institute for Bible Translation, and the title of the draft spelling rules, «Агъул чӀалан орфографин къайдабурин свод». The dictionary has both words («агъул», «чӀал») |
| Space bar corner label | АГЪУЛ | the self-name «агъул», like «ЛЕЗГ», «АВАР», «ДАРГ», «КЪУМ», «ТАБ», «ЛАК» |

The palochka of «чӀал» is Ӏ U+04C0 everywhere in the project. Sources type
it in several ways (U+04C0, the lowercase U+04CF, a Latin I, l or i); the
letter meant is the same.

Nothing else is Aghul yet. **No Aghul translation was invented.**

## What is temporary Russian (needs an Aghul translation)

No verified Aghul translation of the key names or of the keyboard's
settings panel exists (Agisight's `ios-system-keyboard` has no Aghul key
names), so `AghulStrings.swift` uses Russian. Every string below needs a
reviewed Aghul version:

| Field | Russian (current) |
|---|---|
| space | Пробел |
| return key: Go / Send / Done / Next / Continue / Join / Route / Search | Перейти / Отправить / Готово / Далее / Продолжить / Подкл. / Маршрут / Найти |
| emergency call | SOS |
| lettersKey | АБВ |
| deleteWordQuestion | Удалить «…»? |
| no / delete | Нет / Удалить |
| emojiRecents | Недавние |
| back / close | Назад / Клавиатура |
| settingsCaption / settingsTitle | АГУЛЬСКАЯ КЛАВИАТУРА / Настройки |
| pageInput / pageTheme / pageDictionary / pageAbout | Ввод / Тема / Словарь / О клавиатуре |
| sectionLayout / sectionSuggestions / sectionKeys / sectionLearning | Раскладка / Подсказки / Клавиши / Обучение |
| sectionLongPress / sectionTheme | Долгое нажатие (кӀ, хь, ё…) / Тема |
| wordSuggestions / nextWordSuggestion / autoSpace | Подсказки слов / Подсказка следующего слова / Пробел после подсказки |
| doubleSpacePeriod / spaceCursor / spaceCornerToggle | Два пробела — точка / Курсор пробелом / «агъул» на пробеле |
| learnFast / learnNormal / learnSlow / learnUses | Быстро / Обычно / Медленно / N раз(а) |
| calloutShort / calloutNormal / calloutLong / calloutDuration | Короткая задержка / Обычная задержка / Длинная задержка / 0,3 с |
| themeSystem / themeLight / themeDark | Системная / Светлая / Тёмная |
| learnedWordsCaption / noWordsYet | выученные слова / Пока нет слов |
| deleteAll / deleteAllQuestion | Удалить все выученные слова / Удалить все выученные слова? |
| aboutInitial / aboutTitle / aboutByline | А / Агульская клавиатура / Версия … · LekiTech |
| settingsTitle / settingsSubtitle of the layout style | Стандартная / Русская раскладка, ъ на месте щ, Ӏ на месте ы |
| emojiCategoryTitles | Смайлики и люди, Животные и природа, Еда и напитки, Активность, Путешествия и места, Предметы, Символы, Флаги |

Also the extension's `Localizable.xcstrings` («Show «агъул» on the space
bar», en/ru) and the display name «Aghul» / «Агульский» in the keyboard
extension's `InfoPlist.xcstrings` (an Aghul display name could be added as
an `agx` localization once iOS lists the language).

The engine's own labels (for example the explanatory subtitles under the
toggles) follow the system language (en/ru) and are not this keyboard's to
translate.

## The language code

`PrimaryLanguage` of the extension is `agx`, the ISO 639-3 code of Aghul
and a valid BCP 47 language subtag. Like `lbe` and `tab`, and unlike
`lez` and `kum`, it has no display name in Apple's language data:
`Locale.localizedString(forLanguageCode:)` returns nothing for it in
English and in Russian (checked with Foundation on macOS 26.6). The
expected effect is cosmetic: the globe menu shows «Aghul» / «Агульский»
(the extension's own display name) without a language line under it. This
has not been looked at on a device yet. The app cannot supply that line.
The code must not be replaced by another language's to obtain one.

## The containing app

English with Russian translations (`AghulKeyboard/Localizable.xcstrings`,
30 strings), like the sibling apps: «Aghul Keyboard» / «Агульская
клавиатура». No Aghul text there except letters and «Агъул чӀал». The app
shows no contributor credits; attribution of third-party material is in
the repository (`LICENSE`, `Tests/AghulCoreTests/Fixtures/agisight/SOURCE.md`,
`docs/DICTIONARY.md`).

## Icon and colours

`docs/branding/AghulKeyboard_AppIcon_1024.webp` is the owner's approved
artwork as delivered (1024 × 1024, opaque RGB, full bleed): blue bands
above and below, white stripes, a green field with white mountains, a
tower and four eight-pointed stars, and a white keyboard. `scripts/make_icon.py`
checks it and installs it without changing a pixel (`AppIcon-1024.png`,
and `AppLogo.png` at 512 × 512 for the app's header). The app's colours
come from it: `AccentColor` is its green (#026600; #2FA04E in dark mode),
`BrandTint` its blue (#0402C2; #7D8BFF in dark mode). White text on the
green is 7.2 : 1, the blue on white 11.7 : 1.
