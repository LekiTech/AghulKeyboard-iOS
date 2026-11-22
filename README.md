# Aghul Keyboard for iOS

A native iOS keyboard for the Aghul language (Агъул чӀал), developed by
[LekiTech](https://github.com/LekiTech) on the shared **General Keyboard**
engine, next to the Avar, Lezgi, Dargwa, Kumyk, Tabasaran and Lak
keyboards.

The language is called both Agul and Aghul in English. The app uses
**Aghul**, the name of ISO 639-3 (`agx`), Glottolog and Wikipedia and the
one that keeps the «гъ» of the self-name; the evidence is in
[docs/LOCALIZATION.md](docs/LOCALIZATION.md#the-english-name-aghul).

## The keyboard

- **The LekiTech Aghul layout** (a proposal, designed from corpus data;
  not an Apple or Agisight layout): the Russian iOS layout with two keys
  changed. The hard sign **ъ** (2.3 % of all Aghul characters) and the
  palochka **Ӏ** (2.7–3.2 %) have their own keys, where Russian has щ and
  ы, which Aghul uses only in loans.

  ```
  й ц у к е н г ш ъ з х
  ф Ӏ в а п р о л д ж э
  ⇧ я ч с м и т ь б ю ⌫
  ```

- Long press: г → гъ гь гӀ · к → кь кӀ къ · х → хь хъ хӀ · т → тӀ ·
  п → пӀ · ч → чӀ · ц → цӀ · у → уь · д → дж · е → ё · ш → щ · Ӏ → ы.
  These fifteen two-character letters are ordinary Cyrillic sequences and
  can also be typed key by key; the four doubled letters of the alphabet
  (кк пп тт чч) are typed by tapping the key twice. Why this layout, the
  numbers and the alternatives: [docs/LAYOUT.md](docs/LAYOUT.md).
- The palochka is always **Ӏ U+04C0** in what you see and type; lookups use
  ӏ U+04CF internally, so words typed with a Latin I elsewhere still match.
  In Aghul it is also a letter of its own («Ӏу», «яӀар»), and the keyboard
  counts it as one.
- Word suggestions from an offline dictionary of 7,493 Aghul words and
  1,625 word pairs, plus the words and word pairs it learns from your own
  typing (after three uses by default), including next-word suggestions.
  The dictionary is small: its running text is one book, the Gospel of
  Luke, and its other words come from two word lists. Its cleanup was done
  from the evidence in the sources and **has not been verified by a native
  speaker**: 821 dictionary words that the source data had cut in two at
  the palochka were restored, 777 broken rows removed, and 129 entries are
  flagged (5 of them high priority). See
  [docs/DICTIONARY.md](docs/DICTIONARY.md).
- Matches the native iOS keyboard (Apple's measured iPhone grid, key
  previews, callout menus with swipe selection, caps lock,
  auto-capitalization, spacebar cursor control, hold-to-repeat delete),
  light and dark mode, the emoji page, an in-keyboard settings panel.
- Private by design: never asks for Full Access and sends nothing anywhere.
  Learned words live in the keyboard's own storage and can be managed and
  reset from the keyboard's gear key.

Status: **development version, not released on the App Store.** Open for
review by Aghul speakers: the layout's open questions
([docs/LAYOUT.md](docs/LAYOUT.md#open-questions)), the dictionary's review
lists ([docs/dictionary/review/](docs/dictionary/review/)), and an Aghul
translation of the key names and settings panel, which use Russian text
for now ([docs/LOCALIZATION.md](docs/LOCALIZATION.md)).

## Building

The keyboard engine is the shared **General Keyboard** Swift Package
([LekiTech/GeneralKeyboard-iOS](https://github.com/LekiTech/GeneralKeyboard-iOS)),
linked as a local package found next to this checkout, on its `main`
branch:

```
<workspace>/
  GeneralKeyboard-iOS/     the engine package
  AghulKeyboard-iOS/       this repository
```

`GeneralKeyboard-iOS` is a private repository; cloning it needs read access.

The Xcode project references the package as `../../GeneralKeyboard-iOS`
(relative to `AghulKeyboard/AghulKeyboard.xcodeproj`) and the test
package as `../GeneralKeyboard-iOS`; nothing else is required (no tokens,
no package registry). Open
**`AghulKeyboard/AghulKeyboard.xcodeproj`** in Xcode 27, pick the
**`AghulKeyboard`** scheme (it builds and embeds the
`AghulKeyboardExtension` target) and run on a simulator or an iPhone.

```bash
xcodebuild build -project AghulKeyboard/AghulKeyboard.xcodeproj -scheme AghulKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
xcodebuild test -scheme AghulCoreTests-Package \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
```

Installing on an iPhone, step by step: [docs/BUILDING.md](docs/BUILDING.md).

## Identity

Provisional until the first release.

| | Debug (development) | Release (App Store) |
|---|---|---|
| App bundle ID | `org.lekitech.aghulkeyboard.dev` | `org.lekitech.aghulkeyboard` |
| Keyboard extension bundle ID | `org.lekitech.aghulkeyboard.dev.AghulKeyboardExtension` | `org.lekitech.aghulkeyboard.AghulKeyboardExtension` |
| App Group (both targets) | `group.org.lekitech.aghulkeyboard.dev` | `group.org.lekitech.aghulkeyboard` |
| Signing | automatic, the developer's own team | manual: the distribution team adds its team and App Store profiles |

Both targets carry the App Groups entitlement; the group's identifier is
the `AGHUL_APP_GROUP_ID` build setting of each configuration. Learned
words, settings and recent emojis live in the extension's own container,
so nothing is shared with the sibling keyboards.

The keyboard's language is `agx` (ISO 639-3, `PrimaryLanguage` in the
extension's `Info.plist`) and must stay so. iOS has no display name for
`agx`, so the globe menu is expected to list the keyboard by its own name
without a language line under it; that is a limitation of iOS's language
data, not a setting of this project
([docs/LOCALIZATION.md](docs/LOCALIZATION.md#the-language-code)).

## Release and App Store handoff

Debug builds run as they are under the developer's team. The Release
configuration is prepared but deliberately unsigned: it carries the App
Store identifiers, manual signing with `Apple Distribution`, and an empty
team and empty profile names. To archive for the App Store, the
distribution team:

1. Registers the App IDs `org.lekitech.aghulkeyboard` and
   `org.lekitech.aghulkeyboard.AghulKeyboardExtension`, creates the
   App Group `group.org.lekitech.aghulkeyboard`, and enables the App
   Groups capability with that group on both App IDs.
2. Creates an App Store provisioning profile for each of the two App IDs.
3. In the **Release** configuration of both targets (`AghulKeyboard`
   and `AghulKeyboardExtension`) sets `DEVELOPMENT_TEAM` and
   `PROVISIONING_PROFILE_SPECIFIER`. Debug stays as it is.
4. Sets the version in both targets, the same values in each:
   `MARKETING_VERSION` (now 1.0.0) and `CURRENT_PROJECT_VERSION` (now 1).
5. Archives the `AghulKeyboard` scheme (Product → Archive) and uploads
   the archive to App Store Connect.

Before signing is set up, this checks that Release compiles:

```bash
xcodebuild build -project AghulKeyboard/AghulKeyboard.xcodeproj -scheme AghulKeyboard \
  -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

The keyboard does not request Full Access (`RequestsOpenAccess` is false)
and sends nothing anywhere, and `ITSAppUsesNonExemptEncryption` is NO. The
bundle identifiers and the App Group are provisional until the first
upload and must not change after it.

## Repository

```
AghulKeyboard/
  AghulKeyboard.xcodeproj      two targets: the app and the keyboard extension
  AghulKeyboard/               containing app (SwiftUI): install steps, layout,
                               long-press guide, settings and dictionary info
  AghulKeyboardExtension/      the keyboard: AghulDefinition (with the Aghul
                               normalization profile), AghulLayout, AghulStrings,
                               AghulIdentity, KeyboardViewController, Info.plist,
                               aghul_words.sqlite, aghul_bigrams.sqlite
Package.swift, Tests/AghulCoreTests/  product-layer tests through the real engine
  Fixtures/agisight/                  pinned upstream files (MIT) the tests read
scripts/build_dictionary.py           reproducible dictionary build from the v0 data
scripts/derive_source_repairs.py      derives scripts/data/*.tsv from the two upstream sources
scripts/data/                         the four source-repair tables the build applies
scripts/analyze_layout.py             letter statistics and the layout comparison
scripts/make_icon.py                  checks and installs the app icon from docs/branding/
docs/                                 LAYOUT (+ layout/analysis.json), DICTIONARY
                                      (+ dictionary/review/), LOCALIZATION, BUILDING,
                                      branding/ (the icon artwork as delivered)
```

The engine itself (model, views, storage, normalization pipeline,
settings, emoji) is not in this repository; see `GeneralKeyboard-iOS/docs/`.
No engine change was needed for Aghul.

## Organization

Developed by [LekiTech](https://github.com/LekiTech), a team building
digital tools for the languages of Dagestan.

## License

All rights reserved, see [LICENSE](LICENSE). Third-party material and its
licenses are listed there.
