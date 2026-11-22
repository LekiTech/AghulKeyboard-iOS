# The Aghul layout

This is the **proposed LekiTech Aghul layout**. No community or official
Aghul iOS layout existed to copy (see
[What exists upstream](#what-exists-upstream)); it was designed here from
corpus data. It is not an Apple keyboard and has no approval from Apple or
from Agisight. A review by Aghul speakers is open
([open questions](#open-questions)).

## Rows (iPhone)

```
й ц у к е н г ш ъ з х        11 keys
ф Ӏ в а п р о л д ж э        11 keys
⇧ я ч с м и т ь б ю ⌫        9 letters
123 ⚙︎ 😀 🌐  space  ⏎
```

The Russian iOS layout with **two keys changed**: the hard sign **ъ** is
where the Russian keyboard has **щ**, and the palochka **Ӏ** is where it
has **ы**. **щ** is a long press on ш, **ы** a long press on Ӏ. Every other
letter is in its Russian place. Key sizes are those of the Russian keyboard
(11 keys per row, 29.9 pt on a 402 pt iPhone, 27.5 pt on a 375 pt one); the
engine draws the grid with `KeyboardGridModel.nativeCells`. It is the
arrangement of the Dargwa and Tabasaran keyboards.

The number and symbol pages are the Russian iOS pages, unchanged:
`1 2 3 4 5 6 7 8 9 0` / `- / : ; ( ) ₽ & @ "` / `#+= . , ? ! ' ⌫` and
`[ ] { } # % ^ * + =` / `_ \ | ~ < > $ € ¥ •` / `123 . , ? ! ' ⌫`.

## Long press (complete)

| Key | Options (in order) | |
|---|---|---|
| г | гъ гь гӀ | letters of the alphabet, by frequency in web text (0.95 %, 0.89 %, 0.49 % of letters) |
| к | кь кӀ къ | by frequency (1.22 %, 0.48 %, 0.23 %) |
| х | хь хъ хӀ | by frequency (1.14 %, 0.86 %, 0.73 %) |
| т | тӀ | |
| п | пӀ | |
| ч | чӀ | |
| ц | цӀ | |
| у | уь | |
| д | дж | |
| е | ё | no key of its own, as on the Russian keyboard |
| ш | щ | no key of its own, as on the Russian keyboard |
| Ӏ | ы | no key of its own; on the key that took its place |
| 0 | ° | |
| ₽ | $ € £ ¥ ￦ | |
| # | № | |
| . | … | |
| % | ‰ ∞ | |
| = | ≠ ≈ | |
| - | • – — | |
| / | \ | |
| & | § | |
| ? | ¿ | |
| ! | ¡ | |
| ' | ’ ‘ ` | |
| " | ” “ „ » « | |

A digraph option inserts both characters at once (`кӀ` = к U+043A + Ӏ
U+04C0) and follows the shift state: Shift gives «КӀ», «Гъ», «Уь», Caps Lock
«КӀ», «ГЪ», «УЬ». Each of them can also be typed key by key. The palochka
is always **Ӏ U+04C0**, never a Latin I, a lowercase l or the digit 1;
inside the dictionary and the learned-word store it is ӏ U+04CF.

The four doubled letters of the alphabet (**кк пп тт чч**) are typed by
tapping the key twice, which is quicker than any long press, and so they
are not in a popup. «ъ», «ь» and «ж» have no long press.

## Aghul orthography, as verified

Sources: the alphabet plate of the Great Russian Encyclopedia (T. Maisak,
2005; the 2022 article names the sound of «Ӏ»); the Russian and English
Wikipedia articles; the Institute of Linguistics' minority-language site
(minlang.iling-ran.ru, data from T. Maisak and S. Merdanova); S. N.
Gasanova's draft spelling rules, written in Aghul, in the newspaper «Вести
Агула» (2019). All four print the same 53 entries.

- The alphabet was approved by the Dagestan ASSR Council of Ministers on
  10 August 1990 (compilers Sh. A. and I. A. Mazanaev); the first primer is
  from 1992. The norm rests on the speech of the village of Tpig. No
  officially approved spelling rules exist; Gasanova's are a draft.
- **53 entries**: А Б В Г Гъ Гь ГӀ Д Дж Е Ё Ж З И Й К Кк Къ Кь КӀ Л М Н О
  П Пп ПӀ Р С Т Тт ТӀ У Уь Ф Х Хъ Хь ХӀ Ц ЦӀ Ч Чч ЧӀ Ш Щ ъ Ӏ ы ь Э Ю Я.
  Nineteen are written with two characters; four of those are doubled
  letters (кк пп тт чч).
- **The palochka is also a letter of its own**, an alphabet entry between
  ъ and ы: a consonant (Maisak: the epiglottal stop /ʡ/) written at the
  start, in the middle and at the end of a word: «Ӏу», «Ӏуьр», «Ӏекв»,
  «яӀар», «мерӀ», «лиӀ». It is more than a quarter of all palochkas in the
  Gospel of Luke (28 %). The other palochkas are the second character of
  гӀ кӀ пӀ тӀ хӀ цӀ чӀ.
- «ъ» alone is another consonant, the glottal stop («ниъ», «леъ»), the
  second character of гъ къ хъ, the ending of the inessive («хулаъ») and
  the hard sign of Russian loans. «ь» is the second character of гь кь хь
  уь and the soft sign of Russian loans.
- No apostrophe or other mark inside a word; the engine's default word
  separators apply.
- Labialized consonants are written with «в» (кв, гв, кӀв, хъв, чв, ккв …),
  strong consonants by doubling. Both are plain keys.
- «ы», «ё» and «о» occur in loans (and «о» in a few interjections); the
  examples seen for «щ» are Russian. Word-initial /e/ is «э» («эесси»,
  «экьуна»), elsewhere «е».
- Not letters of this alphabet: аь, оь, цц, сс. The IDS word list writes
  some of its words with «аь» and with «ъӀ» for the sound the alphabet
  writes «Ӏ» ([DICTIONARY.md](DICTIONARY.md)).

## Measurements

`scripts/analyze_layout.py` → [layout/analysis.json](layout/analysis.json).
Two independent samples: the keyboard's own dictionary (the Gospel of Luke,
18,108 tokens, 108,950 characters, token-weighted) and Agisight's letter
count of Aghul web text (FineWeb-2, 1.3 million letters,
`agx_monocorpus_freq.csv`).

| | Luke | web text |
|---|---|---|
| Ӏ, percent of all characters | 3.24 | 2.65 |
| ъ | 2.31 | 2.36 |
| ь | 3.77 | 3.42 |
| щ | 0 | 0.02 |
| ы | 0 | 0.07 |
| ё | 0 | 0.00 |
| э | 0.18 | 0.33 |
| ю | 0.10 | 0.04 |
| о | 0.06 | 0.68 |

In Luke the palochka is typed 19.5 times per 100 words and «ъ» 13.9 times;
48 % of all word tokens contain «ъ», «ь» or «Ӏ». The two-character letters
are 11.1 % of all letters. The mean word is 6.0 characters long.

## Candidates compared

A model of typing, not a measurement of people (assumptions at the top of
the script): no suggestion is picked, a letter without a key costs a long
press (0.3 s delay), two thumbs. Per 100 words of Luke:

| | Layout | Long presses | Words needing one | Seconds (0.25 s / 0.18 s a tap) | Thumb travel, pt per character |
|---|---|---|---|---|---|
| A0 | Russian keyboard, Ӏ and ъ under ь (Agisight's basic mapping) | 33.3 | 29 % | 160 / 118 | 52.8 |
| A | Russian keyboard, digraphs under their first letter (Agisight's extended mapping) | 33.3 | 29 % | 154 / 114 | 48.7 |
| **B1** | **ъ on щ's key, Ӏ on ы's key (chosen)** | **0** | **0 %** | **150 / 108** | **52.7** |
| B2 | B1 mirrored: Ӏ on щ's key, ъ on ы's key | 0 | 0 % | 150 / 108 | 53.2 |
| B3 | the Lak arrangement: Ӏ on ы's key, ъ on э's key, щ kept | 1.1 | 1.1 % | 151 / 109 | 54.0 |
| C | Russian layout with ъ and Ӏ as 12th keys | 0 | 0 % | 150 / 108 | 55.9 |
| D | B1 with ъ and ь exchanged | 0 | 0 % | 150 / 108 | 52.2 |

Why B1:

- The Russian layout (A0, A) costs a long press in almost every third
  word. Agisight's extended mapping makes each of them produce two letters
  but does not remove any.
- B1 gives the two frequent letters the keys of the two rarest: «щ» and
  «ы» do not occur in Luke and are 0.02 % and 0.07 % of web text, about
  one long press in 200 words there.
- B3 keeps «щ», which Aghul does not need, and gives up «э», which begins
  native words (1.1 per 100 words).
- C makes every key of the two upper rows 3 pt narrower (26.9 pt instead
  of 29.9 pt on a 402 pt iPhone) for no fewer long presses.
- B2 and D differ from B1 by less than 1 % of thumb travel. B1 is the
  arrangement Dargwa and Tabasaran typists already know, and D would move
  «ь» from its Russian place.

## What exists upstream

Checked at Agisight/ios-system-keyboard `86e000a` and
Agisight/rf-keyboard-corpora `cd7a94e` (both 2026-11-11, MIT):

- `ios-system-keyboard` has **no `layout/agx`** (28 layout folders;
  Avar, Dargwa and Lezgi are there). Its Russian layout
  (`layout/rus/rus-3-rows.yaml`, `rus-longpress.yaml`) is the baseline the
  tests compare against.
- `rf-keyboard-corpora/data/agx/Ali_Kuzhuget/` has
  `keyboard/agx_key_default.json`, an **empty stub** (`"layout_name":
  "Aghul (customized)"`, `"keys": []`, `"long_press": []`);
  `mapping/agx_key_mapping.json`, one entry (Ь → Ӏ);
  `mapping/agx_key_mapping_ext.json`, long presses for the Russian keyboard
  (Г → ГЪ ГЬ ГӀ, Ж → ДЖ, К → КК КЪ КЬ КӀ, П → ПП ПӀ, Т → ТТ ТӀ, У → УЬ,
  Х → ХЪ ХЬ ХӀ, Ц → ЦӀ, Ч → ЧЧ ЧӀ, Ь → Ӏ); and the letter count.

So Agisight provides a letter count and long-press mappings, not a layout.
The digraph callouts take the extended mapping's assignment with three
departures: the options are ordered by frequency, the doubled letters are
left to a double tap, and «дж» sits under «д» (its first letter, like every
other digraph) instead of «ж». The copies used are pinned in
`Tests/AghulCoreTests/Fixtures/agisight/` with their licenses.

## Open questions

1. **Doubled letters on a long press.** Agisight's mapping offers кк пп тт
   чч under a long press; here they are a double tap. «тт» alone is 5.7 per
   100 words. Should they be in the popups as well?
2. **«дж» under «д» or under «ж»?** Agisight puts it under «ж».
3. **The order on «г».** Web text has more «гъ» than «гь»; Luke has more
   «гь» because of «Аллагь». The popup follows web text.
4. **«щ» and «ы» off the keys.** Both are in the alphabet for Russian
   loans. If speakers type many of them, B3 or a 12-key row would have to
   be weighed again.
