# The Aghul dictionary (cleanup version 1)

The keyboard ships two read-only SQLite files in the extension bundle:

| File | Rows | Content |
|---|---|---|
| `aghul_words.sqlite` | 7,493 words | `words(word, base_score)`; score = 10 × count in the text + number of word lists that have the word |
| `aghul_bigrams.sqlite` | 1,625 word pairs | `bigrams(prev, word, weight)`; weight = count of the pair in the text |

They are built by `scripts/build_dictionary.py` from the Aghul files of
`keyboard_data_v0.zip` (language code `agx`) and are in the shape General
Keyboard reads (`GeneralKeyboard-iOS/docs/engine/ARTIFACT_CONTRACT.md`).
Every word is lowercase, NFC, with the palochka as ӏ U+04CF; the keyboard
shows and types Ӏ U+04C0.

## Review status

**No Aghul speaker has reviewed this dictionary.** The fixes below were
made from evidence in the sources, not from knowledge of the language.
What a reviewer should look at first:

- [review/high_priority.csv](dictionary/review/high_priority.csv): 5
  entries of Luke that look like two words printed as one, with no capital
  to prove it;
- [review/flagged.csv](dictionary/review/flagged.csv): all 129 flagged
  entries, kept unchanged;
- [review/merges.csv](dictionary/review/merges.csv): the 14 merges;
- [review/corrections.csv](dictionary/review/corrections.csv): every
  automatic fix (1,962 lines), sortable by rule;
- the [open questions](#open-questions).

## Source data

`keyboard_data_v0.zip` (SHA-256 `8cec9c22…b8ac31`), folder
`keyboard_data/`, built 2026-10-11. Its Aghul files are kept unmodified,
with their checksums, in `../aghul-dictionary/original-v0/` next to this
repository; the build verifies them and never writes there.

| v0 file | |
|---|---|
| `agx_words.sqlite`, `agx_words.tsv` | 7,439 words; the TSV adds the count in the text and the number of word lists |
| `agx_bigrams.sqlite`, `agx_bigrams.tsv` | 1,625 pairs seen at least twice |
| `agx_stats.json` | the builder's own statistics |

Unlike the Dargwa, Tabasaran and Lak data, **none of it is scanned text**.
v0 took three sources (its `build_kb_data.py`, `build_lang("agx")`):

| Source | Kind | Size in v0 |
|---|---|---|
| Gospel of Luke in Aghul, Institute for Bible Translation, 2005, as the file `coverage/corpus/clean_LukeAgul.txt` of github.com/nstsi/agul | running text, typed | 17,977 tokens, 4,352 different words |
| AgulLang, a Russian–Aghul dictionary (agullang.ru), as `preprocessing/get_noun_forms/Agul_dict.csv` of the same repository | word list | 3,054 words |
| Intercontinental Dictionary Series, list 61 «Aghul» (M. Khalilov) | word list | 1,184 words |

The v0 word list is exactly the union of the three; this was checked by
running the v0 tokenizer over them again (7,439 of 7,439 words, every count
equal). The two files of `nstsi/agul` (commit `5a0d84b`, 2022-05-28) are
kept, with checksums, in `../aghul-dictionary/upstream/nstsi-agul-5a0d84b/`.
The repository has no license file; nothing of it is copied here except
words and counts.

## Audit of the v0 data

`review/summary.json` has every number. The form of the rows is sound: all
7,439 words are NFC, lowercase and canonical, none has a Latin letter, a
visible palochka U+04C0, a doubled palochka, a control character or the
same letter three times; every score follows the v0 formula; every pair's
words are rows. The letters are а–я without ё, щ and ы, and the palochka
(in 1,264 words).

The damage is in how v0 read its sources:

1. **AgulLang types the palochka as a Latin «I»** (3,471 times, in 1,665
   of its 4,696 entries). The v0 tokenizer took Cyrillic letters only, so
   it cut every such word at the «I»: «алирхIас» became «алирх» and «ас»,
   «кIечI» became «еч». The v0 list therefore holds 706 pieces that are
   not words of the dictionary and lacks 1,151 words that are (821 of them
   entirely, 330 known from Luke or IDS but without their word-list credit).
2. **88 rows of Luke are two words printed as one.** The upstream cleaning
   deleted every character that is not a Cyrillic letter, a palochka or
   white space; where punctuation stood between two words with no space
   (a quotation or a verse beginning), the words fused: «хьунаяАллагьди».
3. **v0 dropped «Ӏу»** ("two", 45 times in Luke) and «Ӏа» (2): it counted
   the palochka as part of the letter before it and required two letters.
4. **Suffix notations.** AgulLang prints a noun as «агъ (ди, ар)», the
   word with its ergative and plural endings; v0 took «ди», «ар», «бур»,
   «йи» … for words.
5. **The IDS list uses its own notation**: «ъӀ» for the consonant the
   alphabet writes «Ӏ» (its transcription column has one sound, ʔˤ:
   «ъӀуд» next to Luke's «Ӏуд»), «хъӀ къӀ кьӀ гъӀ» for pharyngealized
   consonants, «аь» for a vowel. Its vowels also differ from Luke's
   («саъӀат» / «сеӀет»), so it records another variety of the language.

## What cleanup version 1 does

Six fixes and one merge rule. None respells a word into a form the sources
do not have. The first five are derived from the two upstream files by
`scripts/derive_source_repairs.py` into four small tables
(`scripts/data/*.tsv`), which the build reads; the tables are committed
and pinned by checksum, so the build needs only the v0 files.

| Rule | What | Rows |
|---|---|---|
| **W1** | AgulLang words that v0 cut at the palochka are read whole («алирхӀас», «кӀечӀ», «гӀабдал») and enter as word-list entries | 821 rows added, 330 existing rows credited |
| **P1** | The pieces of those cuts lose their word-list credit; a piece attested nowhere else is removed («алирх», «ас», «абдал») | 674 rows removed; 32 kept (26 words of Luke such as «вас», «ме», and IDS entries) |
| **G1** | A row of Luke with a capital letter inside is split there, and its count goes to the two words («хьунаяАллагьди» → «хьуная» + «аллагьди») | 85 rows |
| **G2** | The same before the name «Ӏиса», whose capital has no lowercase and cannot show the boundary («гъушанасӀисайис») | 3 rows |
| **R1** | «Ӏу» and «Ӏа» come back with their counts in Luke | 2 rows (47 tokens) |
| **F1** | Fifteen suffix notations are removed: ала ани ар ари бур ди ела ер ий ина йи уна уни ура яр. Each stands in AgulLang only as an ending in brackets and is in neither Luke nor IDS | 15 rows removed |
| **S1** | An IDS entry with «ъӀ» (not after х к г) is merged into the same word with «Ӏ» when that word is already a row («ъӀуд» → «Ӏуд», «лиъӀ» → «лиӀ») | 14 merges |

G1 and G2 split 88 rows (89 tokens) into 173 word tokens; 23 of the words
were not rows before («варфаламей», «матфей»); five one-letter words («э»,
«е», «я») cannot be rows and are dropped.

### Totals

| | v0 | cleanup 1 |
|---|---|---|
| Words | 7,439 | 7,493 (777 removed, 845 added, 14 merged) |
| … unchanged from v0 | | 6,182 |
| … in a word list | 3,771 | 4,064 |
| … with a palochka | 1,264 | 2,053 |
| Tokens of Luke counted | 17,977 | 18,108 (−89 fused, +173 their words, +47 «Ӏу» «Ӏа») |
| Sum of scores | 184,008 | 185,734 |
| Word pairs | 1,625 | 1,625 |
| Sum of pair weights | 4,890 | 4,890 |
| Flagged for review | | 129 (5 high priority) |

No fused, removed or merged row was part of a word pair, so the pairs are
those of v0.

### Not changed

- **67 flagged rows** look like two words printed as one but have no
  capital inside. Many such rows are real: Aghul writes case endings,
  clitics and compound verbs together («Ӏисайифас», «ягӀархьуна»). A row
  is flagged only when it occurs once or twice, both halves are words of
  Luke used five times or more, and neither half ends or begins a more
  frequent row. 19 rows meet that; 5 with both halves used twenty times
  or more are high priority («пунапуная», «инсанаргебурис»).
- **57 IDS entries with «ъӀ»** have no twin with «Ӏ» in the data and stay
  («ъӀадат»). «хъӀ», «къӀ» are never merged: «хъӀал» is not «хӀал».

## Review lists

`flagged.csv` (129 rows, `priority`, `word`, `count`, `word_lists`,
`base_score`, `categories`, `notes`), most frequent first:

| Category | Rows | |
|---|---|---|
| word-list spelling outside the school alphabet | 71 | IDS entries with a sign before Ӏ, or with «аь» |
| two-letter word-list entry | 27 | a short word, or part of a dictionary entry |
| possibly two words printed as one | 19 | see above |
| hyphenated entry | 7 | «дад-баб», «уч-учикди»: the keyboard completes the halves separately |
| spelled two ways in the data | 3 | «гӀайа» / «гӀая», «ел» / «эл» |
| very long token | 2 | 20 characters or more |
| possibly a suffix notation | 1 | «вар» in AgulLang «хӀуни (-, вар)» |

## Open questions

1. **Which variety should the dictionary follow?** Luke, AgulLang and IDS
   do not spell alike (Luke «гӀедат», «сеӀет»; IDS «ъӀадат», «саъӀат»).
   The norm rests on the speech of Tpig and has no approved spelling
   rules. All three are kept; the IDS entries have the lowest score.
2. **The IDS notation.** Should the 57 remaining «ъӀ» entries and the
   entries with «хъӀ», «аь» be respelled, removed or kept?
3. **Fused words without a capital** (19 flagged rows).
4. **Suffix notations.** Are any of the fifteen removed endings also words
   of their own? Is «вар» a plural form?
5. **«йа» / «я», «йу» / «ю», «е» / «э».** The draft spelling rules note
   that dictionaries differ; the data has both in a few words.

## Known limitations

- **The text is one book.** 18,108 tokens of the Gospel of Luke: the
  frequent words and all word pairs are biblical («Ӏисайи пуная»,
  «аллагьдин паччагьвел»), and everyday vocabulary comes only from the
  two word lists, without frequencies. The keyboard's own learning (three
  uses by default) is what adapts it to a typist.
- **Names are lowercase rows** («ӏиса», «симон»), like every word; a
  suggestion is capitalized only at the start of a sentence or when the
  typed letters are.
- **One-letter words are not in the dictionary** («э», «е», «я»; the
  engine requires two letters). v0 removed them before counting pairs, so
  a pair may join two words that had such a word between them.
- **Pairs cross sentence ends.** The upstream text has no punctuation, so
  v0 counted pairs across them; only pairs seen twice are kept.
- **AgulLang entries are dictionary forms** (a verb with five of its
  forms, a noun without its case forms), so many inflected forms a typist
  needs are missing until learned.
- The sources' own licenses are unclear or absent (see `LICENSE`); the
  artifacts hold words, counts and pairs, not the texts.

## Rebuilding

```bash
SOURCE_DATE_EPOCH=1795132800 python3 -I scripts/build_dictionary.py
python3 -I scripts/build_dictionary.py --validate
```

The first command rebuilds both artifacts and the review files and runs
the 45 validation checks; with `SOURCE_DATE_EPOCH` set the SQLite files
are byte-identical on every run. The build refuses to overwrite artifacts
of a newer cleanup or content version.

To derive the four repair tables again (only needed to audit them), put
`clean_LukeAgul.txt` and `Agul_dict.csv` of github.com/nstsi/agul at
`5a0d84b` into `../aghul-dictionary/upstream/nstsi-agul-5a0d84b/` and run
`python3 -I scripts/derive_source_repairs.py`; the output must equal the
committed tables.
