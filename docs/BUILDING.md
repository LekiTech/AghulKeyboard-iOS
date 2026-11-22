# Building, signing, running on a device

## Requirements

- Xcode 27 (the project was created with 27.2); iOS 18.0 deployment target.
- `GeneralKeyboard-iOS` checked out next to this repository (`main`). The
  project references it as a local Swift package (`../../GeneralKeyboard-iOS`
  from the `.xcodeproj`); no tokens or registries.

## Targets and identity

| | Debug (development) | Release (App Store) |
|---|---|---|
| App bundle ID | `org.lekitech.aghulkeyboard.dev` | `org.lekitech.aghulkeyboard` |
| Extension bundle ID | `org.lekitech.aghulkeyboard.dev.AghulKeyboardExtension` | `org.lekitech.aghulkeyboard.AghulKeyboardExtension` |
| App Group (`AGHUL_APP_GROUP_ID`, both entitlements) | `group.org.lekitech.aghulkeyboard.dev` | `group.org.lekitech.aghulkeyboard` |
| Signing | Automatic, team `RC94H8KQYA` | Manual, `Apple Distribution`, team and profiles empty |
| Display name | app: Aghul / Агъул чӀал · keyboard: Aghul / Агульский | same |

Debug and Release use different identifiers on purpose: bundle IDs and App
Groups are unique across Apple developer teams, so a Debug build registered
under the developer's team must not take the production identifiers away
from the distribution team. `AghulIdentity.swift` selects the App Group
with `#if DEBUG` to match. The learned-word store (`learned.sqlite`),
settings (`UserDefaults.standard` of the extension) and recent emojis live
in the extension's own container, keyed by its bundle ID, so Aghul never
shares or touches the data of the Avar, Lezgi, Dargwa, Kumyk, Tabasaran or
Lak keyboards. The App Group only carries the inert contribution bridge.

The keyboard definition id (`KeyboardDefinition.id`) is the Release
extension bundle ID and never changes.

## Development build on a physical iPhone

1. Open `AghulKeyboard/AghulKeyboard.xcodeproj`, scheme `AghulKeyboard`,
   configuration Debug (the scheme's default).
2. Select the iPhone as the run destination and press Run. Automatic
   signing with team `RC94H8KQYA` creates the two App IDs, the App Group
   `group.org.lekitech.aghulkeyboard.dev` and the development profiles
   on first use (Xcode asks once; a paid team, so no 7-day expiry).
3. On the phone: Settings → General → Keyboard → Keyboards → Add New
   Keyboard → **Aghul** (on a phone set to Russian: **Агульский**). Then
   hold 🌐 in any text field and pick it.
   The app's own screen repeats these steps and opens Settings.
4. Full Access is never requested and must stay off.

Command line, for a connected device (replace the id with
`xcrun devicectl list devices`):

```bash
xcodebuild build -project AghulKeyboard/AghulKeyboard.xcodeproj -scheme AghulKeyboard \
  -configuration Debug -destination 'id=<device udid>' -allowProvisioningUpdates
```

## Simulator

```bash
xcodebuild build -project AghulKeyboard/AghulKeyboard.xcodeproj -scheme AghulKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
```

Install the built `.app`, enable the keyboard in the simulator's Settings as
above, then type in any text field (Reminders, Safari). Older simulator
runtimes may lack the emoji font; the emoji page then shows boxes there.

Checked on 2026-11-21 on an iPhone 18 Pro Max simulator (iOS 27.2): the
app opens, the keyboard appears from the 🌐 key with the three rows of
`docs/LAYOUT.md`, «Ӏ» and «и» bring up «Ӏисайи» and «Ӏиса» from the
dictionary, a tapped suggestion is inserted with its space, a long press
on «к» inserts «къ», and the emoji page and dark mode work. This is a
simulator check, not a test on a phone and not a review by a speaker.

## Tests

```bash
xcodebuild test -scheme AghulCoreTests-Package \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
```

`Package.swift` compiles the product files of the extension into
`AghulCore` and runs them through the real engine: the definition, the
normalization profile, the palochka convention, the word separators and
the project identity (`AghulDefinitionTests`), the layout against the pinned
Russian baseline, the pinned Agisight Aghul files and the dictionary's
letter frequencies (`AghulLayoutTests`), the shipped artifacts, the
palochka as a letter and the cleanup rules (`DictionaryTests`), typing,
digraph insertion in every case, words that begin with «Ӏ», accepted
suggestions, learning, persistence, settings and the default learning
speed (`TypingAndLearningTests`). 50 tests.

`xcodebuild test` sometimes does not exit after printing the summary of
the last suite; stop it then, the results above the summary stand.

## Release signing (later, by the distribution owner)

The Release configuration carries the App Store identifiers and manual
signing with an empty team and empty profile names. Before the first
archive the distribution team must:

1. register the App IDs `org.lekitech.aghulkeyboard` and
   `org.lekitech.aghulkeyboard.AghulKeyboardExtension` and the App Group
   `group.org.lekitech.aghulkeyboard` in its developer account, with the
   App Groups capability on both App IDs;
2. create two App Store provisioning profiles and set, in the Release
   configuration of each target, `DEVELOPMENT_TEAM[sdk=iphoneos*]` and
   `PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]` (as Avar and Lezgi do);
3. keep Debug untouched, so development builds stay under the developer's
   own team.

Nothing here uses another developer's credentials, and no profile is
committed.

## Conventions

Exactly two targets. No sticker extension, no messenger integrations, no
third-party packages (General Keyboard `docs/ADDING_A_KEYBOARD.md`). Engine
changes go to `GeneralKeyboard-iOS` first; this repository holds only the
Aghul definition, resources, tests and documentation. No engine change was
needed for Aghul: its normalization profile (`aghul-cyrillic`, the palochka
counted as a letter) is a value of the product, in `AghulDefinition.swift`.
