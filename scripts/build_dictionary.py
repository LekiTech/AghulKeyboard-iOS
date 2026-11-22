#!/usr/bin/env python3
"""Build the Aghul keyboard dictionary from the v0 data (cleanup version 1).

Deterministic, Python 3 standard library only. Reads (never writes) the five
v0 Aghul files from keyboard_data_v0.zip, checked against pinned SHA-256 sums:

    agx_words.sqlite  agx_bigrams.sqlite  agx_words.tsv  agx_bigrams.tsv  agx_stats.json

and the four source-repair tables of scripts/data/ (derived from the two
upstream files of v0 by scripts/derive_source_repairs.py, also pinned).

Writes:

    <out>/aghul_words.sqlite     words(word, base_score) + meta   (General Keyboard artifact)
    <out>/aghul_bigrams.sqlite   bigrams(prev, word, weight) + meta
    <review>/corrections.csv     every automatic fix (rules G1 G2 R1 W1 P1 F1)
    <review>/merges.csv          every merge of a variant into an existing word (rule S1)
    <review>/flagged.csv         entries kept unchanged but listed for a linguistic review
    <review>/high_priority.csv   the flagged entries a typist is most likely to meet
    <review>/summary.json        counts of the audit, the fixes, the merges and the flags

Usage, from the repository root (the v0 files sit in
../aghul-dictionary/original-v0 next to this repository):

    python3 -I scripts/build_dictionary.py               # build + validate
    python3 -I scripts/build_dictionary.py --validate    # validate the shipped artifacts only
    python3 -I scripts/build_dictionary.py --source DIR --out DIR --review DIR

Set SOURCE_DATE_EPOCH to make meta.generated_at (and so the sqlite bytes)
reproducible; the rows are identical on every run regardless. The build
refuses to replace artifacts that carry a newer cleanup or content version
than this script (an obsolete checkout cannot overwrite approved data).

The rules are documented in docs/DICTIONARY.md. In short:

  * The Aghul data is not scanned text. Its running text is the Gospel of
    Luke (IBT, 2005), typed; its two word lists are the AgulLang dictionary
    and the Aghul list of the Intercontinental Dictionary Series. What is
    wrong with it came from how v0 read them, and each fix names the place
    in the source that shows it:
      G1  two words of Luke printed as one where the punctuation between
          them was deleted; the capital inside the token proves the boundary
          («хьунаяАллагьди»). The row is split and its count given back to
          the two words;
      G2  the same before the name «Ӏиса», whose capital has no lowercase;
      R1  words v0 dropped because it did not count Ӏ as a letter («Ӏу», two);
      W1  AgulLang words v0 cut at the palochka, which that dictionary types
          as a Latin «I» («кIечI»): read whole and added as word-list entries;
      P1  the pieces those cuts left («алирх», «ас» from «алирхIас»): their
          word-list credit is withdrawn, and a piece attested nowhere else
          is removed;
      F1  suffix notations of AgulLang noun entries («агъ (ди, ар)») that v0
          took for words: removed.
  * One merge rule, S1: a word-list entry that writes «ъӀ» where the school
    alphabet writes «Ӏ» (the IDS notation) is merged into the same word
    with «Ӏ» when that word is already a row.
  * Nothing is respelled into a form the sources do not have. Every other
    doubtful entry stays as it is and is written to flagged.csv.
"""

import argparse
import csv
import hashlib
import json
import os
import re
import sqlite3
import sys
import unicodedata
from collections import Counter, defaultdict
from datetime import datetime, timezone

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SOURCE = os.path.join(os.path.dirname(REPO), "aghul-dictionary", "original-v0")
DEFAULT_OUT = os.path.join(REPO, "AghulKeyboard", "AghulKeyboardExtension")
DEFAULT_REVIEW = os.path.join(REPO, "docs", "dictionary", "review")
DATA = os.path.join(REPO, "scripts", "data")

# keyboard_data_v0.zip (sha256 8cec9c22b314373386dbcbbbe1680d765b4f212de655162197af019402b8ac31),
# folder keyboard_data/, built 2026-10-11. The v0 language code is agx (ISO 639-3).
V0_SHA256 = {
    "agx_words.sqlite": "de6a036ecbe1535681952d80bc04bdef1206e49cb82e2f01100e68bbe6fcf275",
    "agx_bigrams.sqlite": "dddb23dbc6f3e5e584954790a9d19befaecb2f5ad665e3e6a812cc31ecf9754a",
    "agx_words.tsv": "75c85c1b5ab83bd6a0340e00d5214446116ded545e12a81a88e33cfd63b27e70",
    "agx_bigrams.tsv": "e475419cb88602746db7cfaf44409022238ccaee7deed682f4d4f7266d701ec7",
    "agx_stats.json": "ee8c284e31bf10c733f30829f707d319a95a2e886fd7d0af7ffe7778bae91da0",
}
# scripts/data/, written by scripts/derive_source_repairs.py from
# github.com/nstsi/agul at 5a0d84b (clean_LukeAgul.txt, Agul_dict.csv).
REPAIR_SHA256 = {
    "luke_glued_tokens.tsv": "4759041fb8381b0fd54e1e1980f06b162bf06c8a08b592b63d202b05919cda2b",
    "luke_short_words.tsv": "72922c2842ea6b8cad5c1b14af4847b2568ef4fac31a5c7f94f7dc88f60fb879",
    "agullang_palochka_words.tsv": "f544a041f2b5de7bd5d784c4bdc3be767433a2037ddbc8e5a44c4445baf7f60a",
    "agullang_cut_pieces.tsv": "662be7f9f88914869a5797c80ffe895ddc9ca538fd9c3f6ea83ae7a99043de98",
}

LANGUAGE = "agx"
WORDS_ARTIFACT = "aghul_words"
BIGRAMS_ARTIFACT = "aghul_bigrams"
SCHEMA_VERSION = 1
CONTENT_VERSION = 1
NORMALIZATION_PROFILE = "aghul-cyrillic"   # AghulDefinition.swift, NormalizationProfile.id
NORMALIZATION_VERSION = 1
MIN_READER_SCHEMA = 1
CLEANUP_VERSION = 1

# The CREATE statements of the v0 files, which are the General Keyboard
# artifact shape (docs/engine/ARTIFACT_CONTRACT.md §1). The build checks that
# the v0 files carry exactly these and writes them unchanged.
WORDS_SQL = "CREATE TABLE words(word TEXT PRIMARY KEY, base_score INTEGER NOT NULL DEFAULT 0) WITHOUT ROWID"
BIGRAMS_SQL = ("CREATE TABLE bigrams(prev TEXT NOT NULL, word TEXT NOT NULL, weight INTEGER NOT NULL, "
               "PRIMARY KEY(prev, word)) WITHOUT ROWID")
META_SQL = "CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)"

# v0 recorded only the corpus in meta.sources although its builder also
# counted two word lists (build_kb_data.py, build_lang("agx")); all three are
# named here.
SOURCES = {
    "luke_ibt": "Gospel of Luke in Aghul, Institute for Bible Translation, 2005 "
                "(github.com/nstsi/agul, coverage/corpus/clean_LukeAgul.txt); all of the running text",
    "agullang_dict": "AgulLang Russian–Aghul dictionary, agullang.ru "
                     "(github.com/nstsi/agul, preprocessing/get_noun_forms/Agul_dict.csv); word list",
    "ids": "Intercontinental Dictionary Series, CLDF, list 61 «Aghul» (M. Khalilov); word list, 1,184 words",
}

PALOCHKA = "ӏ"               # ӏ U+04CF, the lookup form (TextConventions shows Ӏ U+04C0)
SIGNS = "ъь"
ALPHABET_RE = re.compile(rf"[а-яё{PALOCHKA}]+(?:-[а-яё{PALOCHKA}]+)*")
HIGH_PRIORITY_COUNT = 10     # a flagged word this frequent in a 18,000-token text shows up in everyday use
GLUE_PART_COUNT = 5          # flags: both halves of a possibly glued token are at least this frequent
GLUE_HIGH_PART_COUNT = 20    # … and this frequent for a high-priority flag
BOUND_FORM_COUNT = 3         # a half that also ends (or begins) a token this frequent is a suffix or a compound part
# A flag that says little by itself: it never makes a row high priority.
LOW_SIGNAL = {"two-letter word-list entry"}

# Rule F1. AgulLang prints a noun as «агъ (ди, ар)»: the word, then its
# ergative and plural endings. v0 took the endings for words. Each of these
# stands in Agul_dict.csv only in that place (536 times for «ар», 119 for
# «ди», 89 for «бур», 60 for «йи» …), never as an entry, and is not in Luke
# or in the IDS list. One-letter endings (и, а, у) never were v0 rows.
SUFFIX_NOTATIONS = ("ала", "ани", "ар", "ари", "бур", "ди", "ела", "ер", "ий", "ина", "йи", "уна", "уни", "ура", "яр")
# Kept and flagged: «хIуни (-, вар)» may give a whole plural, not an ending.
POSSIBLE_NOTATIONS = {"вар": "AgulLang «хӏуни (-, вар)»: a plural form of its own, or the ending -вар"}

# ----------------------------------------------------------------- the GK contract
# Mirror of GeneralKeyboard's Normalization.swift with the Aghul profile
# (AghulDefinition.normalization): the Dagestanian Cyrillic repairs, and ь ъ
# as the only digraph tails. The palochka counts as a letter, because in
# Aghul it is one («Ӏу», «яӀ»). Used only to CHECK the rows.
_SWIFT_WHITESPACE = "\t\n\x0b\x0c\r\x85" + "".join(
    chr(cp) for cp in range(0x110000) if unicodedata.category(chr(cp)) in ("Zs", "Zl", "Zp"))
_LOOKALIKES = {"I", "l", "i", "І", "і", "Ӏ"}
_HOMOGLYPHS = {"a": "а", "c": "с", "e": "е", "o": "о", "p": "р", "x": "х",
               "y": "у", "k": "к", "m": "м", "t": "т", "b": "ь", "h": "н"}
_TAILS = {"ь", "ъ"}


def canonical(token):
    t = unicodedata.normalize("NFC", token).strip(_SWIFT_WHITESPACE).lower()
    if any(0x0400 <= ord(ch) <= 0x04FF for ch in t):
        t = "".join(PALOCHKA if ch in _LOOKALIKES else _HOMOGLYPHS.get(ch, ch) for ch in t)
    return unicodedata.normalize("NFC", t)


def letter_count(token):
    return sum(0 if ch in _TAILS else 1 for ch in token)


def is_valid_token(token):
    """Normalization.isValidToken for a canonical token."""
    if not token or len(token) > 64:
        return False
    if any(ch.isspace() or ch.isdigit() for ch in token) or any(ch in token for ch in "@/."):
        return False
    if any(ch.isascii() and ch.isalpha() for ch in token):
        return False
    if any(unicodedata.category(ch) in ("Cc", "Cf") for ch in token):
        return False
    return letter_count(token) >= 2


# ----------------------------------------------------------------- input
def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def ro(path):
    return sqlite3.connect(f"file:{path}?mode=ro", uri=True)


def table_sql(con):
    return {name: sql for name, sql in con.execute("SELECT name, sql FROM sqlite_master WHERE type='table'")}


class Fail(Exception):
    pass


def load(source):
    for name, digest in V0_SHA256.items():
        path = os.path.join(source, name)
        if not os.path.exists(path):
            raise Fail(f"missing v0 file {path}")
        if sha256(path) != digest:
            raise Fail(f"{name}: SHA-256 differs from the pinned v0 file")

    wc, bc = ro(os.path.join(source, "agx_words.sqlite")), ro(os.path.join(source, "agx_bigrams.sqlite"))
    if table_sql(wc) != {"words": WORDS_SQL, "meta": META_SQL}:
        raise Fail("agx_words.sqlite: unexpected schema")
    if table_sql(bc) != {"bigrams": BIGRAMS_SQL, "meta": META_SQL}:
        raise Fail("agx_bigrams.sqlite: unexpected schema")
    sqlite_words = dict(wc.execute("SELECT word, base_score FROM words"))
    sqlite_pairs = {(a, b): w for a, b, w in bc.execute("SELECT prev, word, weight FROM bigrams")}
    v0_meta = dict(wc.execute("SELECT key, value FROM meta"))
    wc.close()
    bc.close()
    if v0_meta.get("language") != LANGUAGE:
        raise Fail(f"agx_words.sqlite: meta.language is {v0_meta.get('language')!r}, expected {LANGUAGE!r}")

    words = {}
    with open(os.path.join(source, "agx_words.tsv"), encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            words[r["word"]] = {
                "score": int(r["base_score"]), "count": int(r["count"]), "clean": int(r["clean_count"]),
                "ocr": int(r["ocr_count"]), "extra": int(r["extra_count"]), "lex": int(r["lexicon_sources"]),
            }
    if {w: r["score"] for w, r in words.items()} != sqlite_words:
        raise Fail("agx_words.tsv and agx_words.sqlite disagree")
    with open(os.path.join(source, "agx_bigrams.tsv"), encoding="utf-8", newline="") as f:
        tsv_pairs = {(r["prev"], r["word"]): int(r["weight"]) for r in csv.DictReader(f, delimiter="\t")}
    if tsv_pairs != sqlite_pairs:
        raise Fail("agx_bigrams.tsv and agx_bigrams.sqlite disagree")
    with open(os.path.join(source, "agx_stats.json"), encoding="utf-8") as f:
        stats = json.load(f)
    return words, sqlite_pairs, v0_meta, stats


def load_repairs():
    for name, digest in REPAIR_SHA256.items():
        path = os.path.join(DATA, name)
        if not os.path.exists(path):
            raise Fail(f"missing repair table {path}")
        if sha256(path) != digest:
            raise Fail(f"{name}: SHA-256 differs from the pinned table (re-run derive_source_repairs.py "
                       "only against the pinned upstream files)")

    def rows(name):
        with open(os.path.join(DATA, name), encoding="utf-8", newline="") as f:
            return list(csv.DictReader(f, delimiter="\t"))

    return {
        "glued": [(r["raw_token"], r["words"].split(" "), int(r["count"]), r["rule"])
                  for r in rows("luke_glued_tokens.tsv")],
        "short": [(r["word"], int(r["count"])) for r in rows("luke_short_words.tsv")],
        "whole": [r["word"] for r in rows("agullang_palochka_words.tsv")],
        "pieces": [r["piece"] for r in rows("agullang_cut_pieces.tsv")],
    }


def v0_score(rec):
    """base_score of the v0 builder: 10 × corpus count + min(9, word lists)."""
    return 10 * rec["count"] + min(9, rec["lex"])


# ----------------------------------------------------------------- audit
def audit(words, pairs):
    inventory = Counter()
    for w in words:
        inventory.update(w)
    canon_groups = defaultdict(list)
    for w in words:
        canon_groups[canonical(w)].append(w)
    mix = Counter()
    for r in words.values():
        mix[" + ".join(k for k, on in (("word list", r["lex"]), ("clean text", r["clean"]), ("ocr", r["ocr"]),
                                       ("frequency list", r["extra"])) if on)] += 1
    after = Counter()
    for w in words:
        for m in re.finditer(PALOCHKA, w):
            after[w[m.start() - 1] if m.start() else "^"] += 1
    return {
        "words": len(words),
        "bigrams": len(pairs),
        "character_inventory": {f"{ch} U+{ord(ch):04X}": n for ch, n in
                                sorted(inventory.items(), key=lambda kv: (-kv[1], kv[0]))},
        "palochka_after": dict(sorted(after.items(), key=lambda kv: (-kv[1], kv[0]))),
        "not_nfc": sorted(w for w in words if unicodedata.normalize("NFC", w) != w),
        "not_lowercase": sorted(w for w in words if w != w.lower()),
        "not_canonical": sorted(w for w in words if canonical(w) != w),
        "canonical_collisions": sorted(ws for ws in canon_groups.values() if len(ws) > 1),
        "contract_invalid": sorted(w for w in words if not is_valid_token(w)),
        "outside_alphabet": sorted(w for w in words if not ALPHABET_RE.fullmatch(w)),
        "latin_letters": sorted(w for w in words if any(ch.isascii() and ch.isalpha() for ch in w)),
        "visible_palochka_u04c0": sorted(w for w in words if "Ӏ" in w),
        "replacement_or_control_chars": sorted(
            w for w in words if any(ch == "�" or unicodedata.category(ch) in ("Cc", "Cf", "Co", "Cs")
                                    for ch in w)),
        "hyphenated": sum(1 for w in words if "-" in w),
        "with_palochka": sum(1 for w in words if PALOCHKA in w),
        "doubled_palochka": sorted(w for w in words if PALOCHKA * 2 in w),
        "same_letter_three_times": sorted(w for w in words if re.search(r"(.)\1\1", w)),
        "score_formula_mismatch": sorted(w for w, r in words.items() if r["score"] != v0_score(r)),
        "count_mismatch": sorted(w for w, r in words.items()
                                 if r["count"] != r["clean"] + r["ocr"] + r["extra"]),
        "source_mix": dict(sorted(mix.items(), key=lambda kv: -kv[1])),
        "in_word_lists": sum(1 for r in words.values() if r["lex"] > 0),
        "word_lists_only": sum(1 for r in words.values() if r["lex"] > 0 and r["count"] == 0),
        "text_only": sum(1 for r in words.values() if r["lex"] == 0),
        "corpus_tokens": {"ocr": sum(r["ocr"] for r in words.values()),
                          "clean_text": sum(r["clean"] for r in words.values())},
        "bigram_orphans": sum(1 for a, b in pairs if a not in words or b not in words),
        "bigram_weight_below_2": sum(1 for v in pairs.values() if v < 2),
        "bigram_self_pairs": sorted(f"{a} {b}" for a, b in pairs if a == b),
    }


# ----------------------------------------------------------------- fixes
G1 = "G1 two words of Luke printed as one (capital inside the token)"
G2 = "G2 two words of Luke printed as one (before the name Ӏиса)"
R1 = "R1 word of Luke dropped by v0 (Ӏ not counted as a letter)"
W1 = "W1 AgulLang word cut at its Latin-I palochka, read whole"
P1 = "P1 piece of an AgulLang word cut at its palochka"
F1 = "F1 suffix notation of an AgulLang noun entry"
S1 = "S1 «ъӏ» of the IDS list for the «ӏ» of the alphabet"
RULES = {"G1": G1, "G2": G2}
IDS_GLOTTAL = re.compile(f"(?<![хкг])ъ{PALOCHKA}")


def new_row():
    return {"score": 0, "count": 0, "clean": 0, "ocr": 0, "extra": 0, "lex": 0}


def apply_fixes(words, pairs, repairs):
    """final rows, the log of fixes [(rule, action, entry, result, tokens, note)] and the merges."""
    final = {w: dict(r) for w, r in words.items()}
    log = []
    in_pairs = {w for pair in pairs for w in pair}

    def remove(w, why):
        if w in in_pairs:
            raise Fail(f"{why}: {w} is part of a bigram")
        del final[w]

    # W1 / P1: the AgulLang word list as the dictionary prints it.
    for w in repairs["whole"]:
        if canonical(w) != w or not is_valid_token(w) or not ALPHABET_RE.fullmatch(w):
            raise Fail(f"W1: {w!r} is not a canonical Aghul token")
        existed = w in final
        final.setdefault(w, new_row())["lex"] += 1
        log.append((W1, "word-list credit" if existed else "row added", w, w, 0,
                    "already a row (Luke or IDS)" if existed else ""))
    for w in repairs["pieces"]:
        r = final.get(w)
        if r is None or r["lex"] < 1:
            raise Fail(f"P1: {w!r} is not a v0 row with a word-list credit")
        r["lex"] -= 1
        if r["count"] == 0 and r["lex"] == 0:
            remove(w, "P1")
            log.append((P1, "row removed", w, "", 0, ""))
        else:
            log.append((P1, "word-list credit withdrawn", w, w, 0,
                        "kept: " + ("in Luke" if r["count"] else "in the IDS list")))

    # F1
    for w in SUFFIX_NOTATIONS:
        r = final.get(w)
        if r is None or r["count"] or r["lex"] != 1:
            raise Fail(f"F1: {w!r} is not a word-list-only row of one list")
        remove(w, "F1")
        log.append((F1, "row removed", w, "", 0, ""))

    # G1 / G2
    for raw, parts, n, rule in repairs["glued"]:
        token = canonical(raw)
        r = final.get(token)
        if r is None or r["count"] != n or r["lex"]:
            raise Fail(f"{rule}: {raw!r} is not a Luke-only row with count {n}")
        if "".join(parts) != token:
            raise Fail(f"{rule}: {parts} do not make up {token}")
        remove(token, rule)
        kept, notes = [], []
        for p in parts:
            if not is_valid_token(p):
                notes.append(f"«{p}» is one letter: no row")
                continue
            if p not in final:
                notes.append(f"new row {p}")
            t = final.setdefault(p, new_row())
            t["count"] += n
            t["clean"] += n
            kept.append(p)
        log.append((RULES[rule], "row split", raw, " + ".join(kept), n, "; ".join(notes)))

    # R1
    for w, n in repairs["short"]:
        if canonical(w) != w or not is_valid_token(w) or (w in final and final[w]["count"]):
            raise Fail(f"R1: {w!r} cannot be restored")
        existed = w in final
        t = final.setdefault(w, new_row())
        t["count"] += n
        t["clean"] += n
        log.append((R1, "count restored" if existed else "row added", w, w, n,
                    "an AgulLang entry as well" if existed else ""))

    # S1. Only the «ъӏ» that stands for one sound (IDS ʔˤ); after х, к, г the
    # «ъ» belongs to «хъ», «къ», «гъ» and the «ӏ» marks a pharyngealized
    # consonant the alphabet has no letter for («хъӏал» is not «хӏал»).
    merges = []
    for w in sorted(final):
        r = final[w]
        if not IDS_GLOTTAL.search(w) or r["count"]:
            continue
        target = IDS_GLOTTAL.sub(PALOCHKA, w)
        if target in final:
            t = final[target]
            before = dict(t)
            t["lex"] = max(t["lex"], r["lex"])
            remove(w, "S1")
            merges.append((w, target, S1, before["count"], before["lex"], t["lex"]))

    for r in final.values():
        r["score"] = v0_score(r)
    return final, log, merges


# ----------------------------------------------------------------- flags
def flag_entries(final):
    """Entries kept unchanged and listed for review: {word: [(category, note)]}."""
    flags = defaultdict(list)

    def count(w):
        return final[w]["count"] if w in final else 0

    # Halves that also end or begin a frequent token are suffixes, clitics
    # or parts of compound verbs («ӏисайифас» 16, «ягӏархьуна» 4), written
    # together on purpose; they are not evidence of glued words.
    splits = defaultdict(list)
    bound_end, bound_start = set(), set()
    for w, r in final.items():
        if r["count"] == 0 or "-" in w:
            continue
        for i in range(2, len(w) - 1):
            a, b = w[:i], w[i:]
            if count(a) and count(b) and letter_count(a) >= 3 and letter_count(b) >= 3:
                splits[w].append((a, b))
                if r["count"] >= BOUND_FORM_COUNT:
                    bound_start.add(a)
                    bound_end.add(b)

    for w, r in final.items():
        word_list_only = r["count"] == 0
        if r["lex"] == 0 and r["count"] <= 2:
            best = None
            for a, b in splits.get(w, ()):
                if a in bound_start or b in bound_end:
                    continue
                low = min(count(a), count(b))
                if low >= GLUE_PART_COUNT and (best is None or low > best[0]):
                    best = (low, a, b)
            if best:
                flags[w].append(("possibly two words printed as one",
                                 f"{best[1]} ({count(best[1])}) + {best[2]} ({count(best[2])}): both are frequent "
                                 "words of Luke and the text has no capital to prove the boundary; "
                                 "or a compound written as one word"))
        if len(w) >= 20:
            flags[w].append(("very long token", "possibly several words printed as one"))
        if word_list_only:
            marks = []
            if re.search(f"[{SIGNS}]{PALOCHKA}", w):
                marks.append("a sign before ӏ (IDS: «ъӏ» for the sound the alphabet writes «ӏ», "
                             "«хъӏ къӏ кьӏ гъӏ» for pharyngealized consonants)")
            if "аь" in w or "оь" in w:
                marks.append("«аь» / «оь», which are not letters of the alphabet")
            if marks:
                flags[w].append(("word-list spelling outside the school alphabet", "; ".join(marks)))
            if letter_count(w) == 2 and len(w) == 2:
                flags[w].append(("two-letter word-list entry", "a short word, or part of a dictionary entry"))
        if "-" in w:
            flags[w].append(("hyphenated entry", "typed with a hyphen: the keyboard completes its halves as "
                             "separate words"))
        if w in POSSIBLE_NOTATIONS:
            flags[w].append(("possibly a suffix notation", POSSIBLE_NOTATIONS[w]))
        for a, b in (("йа", "я"), ("йу", "ю")):
            for x, y in ((a, b), (b, a)):
                if x in w and w.replace(x, y) in final:
                    flags[w].append(("spelled two ways in the data",
                                     f"also {w.replace(x, y)} ({count(w.replace(x, y))}): «{a}» and «{b}»"))
        if w[0] == "е" and "э" + w[1:] in final:
            flags[w].append(("spelled two ways in the data",
                             f"also э{w[1:]} ({count('э' + w[1:])}): «э» and «е» at the start of a word"))
    return flags


def is_high_priority(rec, items):
    if any(c == "possibly two words printed as one" and
           min(int(x) for x in re.findall(r"\((\d+)\)", n)[:2]) >= GLUE_HIGH_PART_COUNT for c, n in items):
        return True
    return rec["count"] >= HIGH_PRIORITY_COUNT and any(c not in LOW_SIGNAL for c, _ in items)


# ----------------------------------------------------------------- output
def generated_at():
    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    t = datetime.fromtimestamp(int(epoch), timezone.utc) if epoch else datetime.now(timezone.utc)
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def guard_existing(out):
    """Refuse to replace artifacts built by a newer cleanup or content version."""
    for artifact_name in (WORDS_ARTIFACT, BIGRAMS_ARTIFACT):
        path = os.path.join(out, artifact_name + ".sqlite")
        if not os.path.exists(path):
            continue
        con = ro(path)
        try:
            meta = dict(con.execute("SELECT key, value FROM meta"))
        except sqlite3.Error:
            meta = {}
        finally:
            con.close()
        for key, ours in (("cleanup_version", CLEANUP_VERSION), ("content_version", CONTENT_VERSION),
                          ("schema_version", SCHEMA_VERSION)):
            theirs = meta.get(key)
            if theirs is not None and theirs.isdigit() and int(theirs) > ours:
                raise Fail(f"{path} has {key} {theirs}, newer than this script's {ours}: "
                           "refusing to overwrite it with older data")


def write_artifacts(out, final, pairs):
    os.makedirs(out, exist_ok=True)
    common = [
        ("schema_version", str(SCHEMA_VERSION)), ("content_version", str(CONTENT_VERSION)),
        ("normalization_version", str(NORMALIZATION_VERSION)), ("normalization_profile", NORMALIZATION_PROFILE),
        ("min_reader_schema", str(MIN_READER_SCHEMA)), ("cleanup_version", str(CLEANUP_VERSION)),
        ("generated_at", generated_at()), ("language", LANGUAGE),
        ("sources", json.dumps(SOURCES, ensure_ascii=False, sort_keys=True)),
    ]
    repairs = sorted(REPAIR_SHA256)
    specs = [
        (WORDS_ARTIFACT, WORDS_SQL, "INSERT INTO words(word, base_score) VALUES(?, ?)",
         sorted((w, r["score"]) for w, r in final.items()), ["agx_words.sqlite", "agx_words.tsv"] + repairs),
        (BIGRAMS_ARTIFACT, BIGRAMS_SQL, "INSERT INTO bigrams(prev, word, weight) VALUES(?, ?, ?)",
         sorted((a, b, v) for (a, b), v in pairs.items()), ["agx_bigrams.sqlite", "agx_bigrams.tsv", "agx_words.tsv"]),
    ]
    digests = {**V0_SHA256, **REPAIR_SHA256}
    for artifact_name, create, insert, rows, inputs in specs:
        path = os.path.join(out, artifact_name + ".sqlite")
        tmp = path + ".tmp"
        if os.path.exists(tmp):
            os.remove(tmp)
        con = sqlite3.connect(tmp)
        con.execute("PRAGMA page_size = 4096")
        con.execute(create)
        con.execute(META_SQL)
        con.executemany(insert, rows)
        derived = json.dumps({n: digests[n] for n in inputs}, sort_keys=True)
        meta = [("artifact", artifact_name)] + common + [("row_count", str(len(rows))), ("derived_from", derived)]
        con.executemany("INSERT INTO meta(key, value) VALUES(?, ?)", sorted(meta))
        con.commit()
        con.execute("VACUUM")
        con.close()
        os.replace(tmp, path)


FLAG_HEADER = ["priority", "word", "count", "word_lists", "base_score", "categories", "notes"]


def write_reviews(review, final, log, merges, flags, summary):
    os.makedirs(review, exist_ok=True)
    with open(os.path.join(review, "corrections.csv"), "w", encoding="utf-8", newline="") as f:
        wr = csv.writer(f, lineterminator="\n")
        wr.writerow(["rule", "action", "entry", "result", "tokens", "note"])
        for row in sorted(log, key=lambda r: (r[0], r[1], r[2])):
            wr.writerow(row)
    with open(os.path.join(review, "merges.csv"), "w", encoding="utf-8", newline="") as f:
        wr = csv.writer(f, lineterminator="\n")
        wr.writerow(["source", "target", "rule", "target_count", "target_word_lists_before",
                     "target_word_lists_after"])
        wr.writerows(merges)
    rows = []
    for w, items in flags.items():
        r = final[w]
        prio = "high" if is_high_priority(r, items) else "normal"
        rows.append((prio != "high", -r["count"], w, [prio, w, r["count"], r["lex"], r["score"],
                                                       "; ".join(c for c, _ in items),
                                                       "; ".join(n for _, n in items)]))
    rows.sort()
    for name, keep in (("flagged.csv", lambda row: True), ("high_priority.csv", lambda row: row[0] == "high")):
        with open(os.path.join(review, name), "w", encoding="utf-8", newline="") as f:
            wr = csv.writer(f, lineterminator="\n")
            wr.writerow(FLAG_HEADER)
            for *_, row in rows:
                if keep(row):
                    wr.writerow(row)
    with open(os.path.join(review, "summary.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=1, sort_keys=False)
        f.write("\n")


# ----------------------------------------------------------------- validation
# Pinned so that a rule change cannot slip through unnoticed.
EXPECTED_WORDS = 7493
EXPECTED_BIGRAMS = 1625
KEPT_WITH_IDS_SIGN_PALOCHKA = 57     # «ъӏ» rows with no «ӏ» twin: flagged, not merged


def validate(out):
    results = []

    def check(name, ok, detail=""):
        results.append((name, bool(ok), detail))

    wp, bp = os.path.join(out, WORDS_ARTIFACT + ".sqlite"), os.path.join(out, BIGRAMS_ARTIFACT + ".sqlite")
    wc, bc = ro(wp), ro(bp)
    for con, table, artifact_name, create, expected in ((wc, "words", WORDS_ARTIFACT, WORDS_SQL, EXPECTED_WORDS),
                                                        (bc, "bigrams", BIGRAMS_ARTIFACT, BIGRAMS_SQL,
                                                         EXPECTED_BIGRAMS)):
        meta = dict(con.execute("SELECT key, value FROM meta"))
        n = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        check(f"{artifact_name}: meta.artifact", meta.get("artifact") == artifact_name, meta.get("artifact"))
        check(f"{artifact_name}: meta.row_count == COUNT(*) ({n})", meta.get("row_count") == str(n),
              meta.get("row_count"))
        check(f"{artifact_name}: {expected} rows (cleanup version {CLEANUP_VERSION})", n == expected, str(n))
        for k, v in (("schema_version", SCHEMA_VERSION), ("content_version", CONTENT_VERSION),
                     ("normalization_version", NORMALIZATION_VERSION),
                     ("normalization_profile", NORMALIZATION_PROFILE), ("min_reader_schema", MIN_READER_SCHEMA),
                     ("cleanup_version", CLEANUP_VERSION), ("language", LANGUAGE)):
            check(f"{artifact_name}: meta.{k} == {v}", meta.get(k) == str(v), meta.get(k))
        for k in ("generated_at", "sources", "derived_from"):
            check(f"{artifact_name}: meta.{k} present", bool(meta.get(k)))
        check(f"{artifact_name}: schema is the General Keyboard artifact shape",
              table_sql(con) == {table: create, "meta": META_SQL})
        check(f"{artifact_name}: page_size 4096", con.execute("PRAGMA page_size").fetchone()[0] == 4096)
        check(f"{artifact_name}: vacuumed", con.execute("PRAGMA freelist_count").fetchone()[0] == 0)
        check(f"{artifact_name}: integrity_check", con.execute("PRAGMA integrity_check").fetchone()[0] == "ok")
    words = dict(wc.execute("SELECT word, base_score FROM words"))
    pairs = list(bc.execute("SELECT prev, word, weight FROM bigrams"))
    bad = [w for w in words if canonical(w) != w]
    check("every word is canonical under the Aghul profile", not bad, ", ".join(bad[:5]))
    bad = [w for w in words if not is_valid_token(w)]
    check("every word passes the token contract", not bad, ", ".join(bad[:5]))
    bad = [w for w in words if not ALPHABET_RE.fullmatch(w)]
    check("every word uses only а–я, ё, ӏ (U+04CF) and inner hyphens", not bad, ", ".join(bad[:5]))
    check("no visible palochka U+04C0 in lookup keys", not any("Ӏ" in w for w in words))
    check("no doubled palochka", not any(PALOCHKA * 2 in w for w in words))
    left = sorted(w for w in words if "ъ" + PALOCHKA in w)
    check(f"«ъӏ» is left only in the {KEPT_WITH_IDS_SIGN_PALOCHKA} flagged rows of the IDS list",
          len(left) == KEPT_WITH_IDS_SIGN_PALOCHKA, str(len(left)))
    bad = [w for w in SUFFIX_NOTATIONS if w in words]
    check("no suffix notation is a row", not bad, ", ".join(bad))
    check("«ӏу» (two) is a row", "ӏу" in words)
    check("every base_score >= 1", all(s >= 1 for s in words.values()))
    bad = [(a, b) for a, b, _ in pairs if a not in words or b not in words]
    check("both words of every bigram are rows of the words artifact", not bad, str(bad[:3]))
    check("every bigram weight >= 2", all(v >= 2 for _, _, v in pairs))
    wc.close()
    bc.close()
    return results


# ----------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", default=DEFAULT_SOURCE, help="folder with the five v0 agx_* files")
    ap.add_argument("--out", default=DEFAULT_OUT, help="where the two artifacts are written")
    ap.add_argument("--review", default=DEFAULT_REVIEW, help="where the review files are written")
    ap.add_argument("--validate", action="store_true", help="only validate the artifacts in --out")
    args = ap.parse_args()

    def report(results):
        for name, ok, detail in results:
            print(("PASS " if ok else "FAIL ") + name + (f"  [{detail}]" if detail and not ok else ""))
        return 0 if all(ok for _, ok, _ in results) else 1

    if args.validate:
        return report(validate(args.out))
    try:
        guard_existing(args.out)
        words, pairs, v0_meta, stats = load(args.source)
        repairs = load_repairs()
    except Fail as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    a = audit(words, pairs)
    hard = {k: a[k] for k in ("not_nfc", "not_lowercase", "not_canonical", "canonical_collisions",
                              "contract_invalid", "outside_alphabet", "latin_letters", "visible_palochka_u04c0",
                              "replacement_or_control_chars", "score_formula_mismatch", "count_mismatch")
            if a[k]}
    if hard or a["bigram_orphans"] or a["bigram_weight_below_2"]:
        print("error: the v0 data breaks an assumption of this build:",
              json.dumps(hard, ensure_ascii=False)[:2000], file=sys.stderr)
        return 2

    try:
        final, log, merges = apply_fixes(words, pairs, repairs)
    except Fail as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    flags = flag_entries(final)

    by_rule = Counter((rule.split()[0], action) for rule, action, *_ in log)
    by_cat = Counter(c for items in flags.values() for c, _ in items)
    by_cat_high = Counter(c for w, items in flags.items() if is_high_priority(final[w], items)
                          for c, _ in items)
    glued_tokens = sum(n for _, _, n, _ in repairs["glued"])
    summary = {
        "input": {"archive": "keyboard_data_v0.zip / keyboard_data/", "files": V0_SHA256,
                  "repair_tables": REPAIR_SHA256,
                  "v0_generated_at": v0_meta.get("generated_at"), "v0_sources": stats.get("sources")},
        "audit": a,
        "fixes": {
            "by_rule_and_action": {f"{rule} {action}": n for (rule, action), n in sorted(by_rule.items())},
            "rows_removed": sum(1 for _, action, *_ in log if action == "row removed")
                            + sum(1 for _, action, *_ in log if action == "row split"),
            "rows_added": sum(1 for _, action, *_ in log if action == "row added")
                          + sum(note.count("new row") for *_, note in log),
            "glued_rows_split": len(repairs["glued"]),
            "glued_tokens": glued_tokens,
            "respelled": 0,
        },
        "merges": {"total": len(merges), "by_rule": {"S1": len(merges)}},
        "flags": {"words": len(flags),
                  "high_priority": sum(1 for w, items in flags.items() if is_high_priority(final[w], items)),
                  "by_category": dict(sorted(by_cat.items(), key=lambda kv: (-kv[1], kv[0]))),
                  "high_priority_by_category": dict(sorted(by_cat_high.items(), key=lambda kv: (-kv[1], kv[0])))},
        "output": {"words": len(final), "bigrams": len(pairs),
                   "words_unchanged_from_v0": sum(1 for w, r in final.items() if words.get(w) == r),
                   "words_in_word_lists": sum(1 for r in final.values() if r["lex"] > 0),
                   "words_with_palochka": sum(1 for w in final if PALOCHKA in w),
                   "corpus_tokens": sum(r["count"] for r in final.values()),
                   "corpus_tokens_v0": sum(r["count"] for r in words.values()),
                   "base_score_total": sum(r["score"] for r in final.values()),
                   "base_score_total_v0": sum(r["score"] for r in words.values()),
                   "bigram_weight_total": sum(pairs.values()),
                   "bigram_weight_total_v0": sum(pairs.values())},
    }
    write_artifacts(args.out, final, pairs)
    write_reviews(args.review, final, log, merges, flags, summary)
    results = validate(args.out)
    print(json.dumps({k: summary[k] for k in ("fixes", "merges", "flags", "output")}, ensure_ascii=False, indent=1)[:6000])
    return report(results)


if __name__ == "__main__":
    sys.exit(main())
