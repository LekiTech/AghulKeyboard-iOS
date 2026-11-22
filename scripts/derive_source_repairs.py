#!/usr/bin/env python3
"""Derive the source-repair tables of the Aghul dictionary (scripts/data/*.tsv).

The v0 Aghul data (keyboard_data_v0.zip, agx_*) was built from three sources.
Two of them are files of github.com/nstsi/agul at commit
5a0d84b830cde71ca94916fa1ef2f6b2d262693f (2022-05-28):

    coverage/corpus/clean_LukeAgul.txt
        the Gospel of Luke in Aghul (Institute for Bible Translation, 2005)
        with punctuation, digits and hyphens already deleted by the
        repository's own clean_corpus.ipynb;
    preprocessing/get_noun_forms/Agul_dict.csv
        the Russian–Aghul dictionary of agullang.ru.

The v0 builder (build_kb_data.py) left three kinds of damage that cannot be
seen in the v0 files alone but are plain in these two. This script reads
the two files, checked against pinned SHA-256 sums, re-runs the v0
tokenizer on them, and writes four small tables that
scripts/build_dictionary.py applies:

    luke_glued_tokens.tsv        raw token, its words, v0 count, rule
        G1  two words printed as one where the cleaning deleted the
            punctuation between them; the capital letter inside the token
            proves the boundary («хьунаяАллагьди» = «хьуная» + «Аллагьди»);
        G2  the same before the name «Ӏиса», whose capital palochka has no
            lowercase form in the text and so cannot show the boundary
            («гъушанасӀисайис» = «гъушанас» + «Ӏисайис»).
    luke_short_words.tsv         word, count
        R1  words v0 dropped because it did not count the palochka as a
            letter: «Ӏу» ("two") is one letter by v0's rule and two by the
            Aghul alphabet, where Ӏ is a letter of its own.
    agullang_palochka_words.tsv  word
        W1  the dictionary writes the palochka as a Latin «I». The v0
            tokenizer took only Cyrillic letters, so it cut every such word
            at the «I» («кIечI» → «к», «еч»). These are the words read
            whole, with the palochka.
    agullang_cut_pieces.tsv      piece
        P1  the pieces those cuts left in the v0 word list («алирх», «ас»
            from «алирхIас»), which are not words of the dictionary.

Usage (the upstream files sit next to this repository, like the v0 data):

    python3 -I scripts/derive_source_repairs.py
    python3 -I scripts/derive_source_repairs.py --upstream DIR --source DIR --out DIR

The tables are committed; the dictionary build reads them and never needs
the upstream files. Running this again must reproduce them byte for byte.
"""

import argparse
import csv
import hashlib
import os
import re
import sys
import unicodedata
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKSPACE = os.path.dirname(REPO)
DEFAULT_UPSTREAM = os.path.join(WORKSPACE, "aghul-dictionary", "upstream", "nstsi-agul-5a0d84b")
DEFAULT_SOURCE = os.path.join(WORKSPACE, "aghul-dictionary", "original-v0")
DEFAULT_OUT = os.path.join(REPO, "scripts", "data")

UPSTREAM_COMMIT = "5a0d84b830cde71ca94916fa1ef2f6b2d262693f"
UPSTREAM_SHA256 = {
    "clean_LukeAgul.txt": "815247cbb4731b60b90c201049ebe01d9402f4bf470997648823b54d7ace0608",
    "Agul_dict.csv": "9c8895ee973440bb5e8863d05f31f8991d71518764495d2f8d5df77b0e33c51e",
}
V0_WORDS_TSV_SHA256 = "75c85c1b5ab83bd6a0340e00d5214446116ded545e12a81a88e33cfd63b27e70"

PALOCHKA = "ӏ"          # U+04CF, the lookup form
CAPITAL_PALOCHKA = "Ӏ"  # U+04C0, the only palochka of the Luke text
NAME = PALOCHKA + "иса"  # «Ӏиса» (Jesus), the stem rule G2 looks for

# ----------------------------------------------------------------- the v0 tokenizer
# Copied from build_kb_data.py (v0): what it did to these two files.
_CYR = "Ѐ-ӿ"
V0_TOKEN = re.compile(rf"[{_CYR}]+(?:-[{_CYR}]+)*")
_V0_LOOKALIKES = {"I", "l", "i", "І", "і", CAPITAL_PALOCHKA, "1", "!", "|", "[", "]", "{", "}", "‡", "†"}
_V0_HOMOGLYPHS = {"a": "а", "c": "с", "e": "е", "o": "о", "p": "р", "x": "х", "y": "у",
                  "k": "к", "m": "м", "t": "т", "b": "ь", "h": "н"}
_V0_ALPHABET = set("абвгдежзийклмнопрстуфхцчшщъыьэюяё") | {PALOCHKA}
_INNER = re.compile(rf"(?<=[{_CYR}])[IlіІ1](?=[{_CYR}])")
_END = re.compile(rf"(?<=[{_CYR}])[IlіІ](?![{_CYR}A-Za-z])")
_START = re.compile(rf"(?<![{_CYR}A-Za-z])[IІ](?=[а-яё])")


def v0_repair_text(text):
    """repair_text of the v0 builder; it ran on the corpus, not on the word lists."""
    text = unicodedata.normalize("NFC", text)
    for rx in (_INNER, _END, _START):
        text = rx.sub(PALOCHKA, text)
    return text


def v0_normalize(token):
    t = unicodedata.normalize("NFC", token).strip().lower()
    t = "".join(PALOCHKA if ch in _V0_LOOKALIKES else ch for ch in t)
    return unicodedata.normalize("NFC", "".join(_V0_HOMOGLYPHS.get(ch, ch) for ch in t))


def v0_valid(token):
    if not token or len(token) > 40 or token.startswith("-") or token.endswith("-") or "--" in token:
        return False
    if sum(0 if ch in (PALOCHKA, "ь", "ъ", "-") else 1 for ch in token) < 2:
        return False
    return all(ch in _V0_ALPHABET or ch == "-" for ch in token)


def aghul_valid(token):
    """The token contract under the Aghul profile: Ӏ is a letter, ь and ъ are not."""
    if not token or len(token) > 40 or token.startswith("-") or token.endswith("-") or "--" in token:
        return False
    if sum(0 if ch in ("ь", "ъ", "-") else 1 for ch in token) < 2:
        return False
    return all(ch in _V0_ALPHABET or ch == "-" for ch in token)


class Fail(Exception):
    pass


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


# ----------------------------------------------------------------- Luke
INNER_CAPITAL = re.compile(r"(?<=.)[А-ЯЁ]")
PART = re.compile(rf"^[а-яё{CAPITAL_PALOCHKA}]+|[А-ЯЁ][а-яё{CAPITAL_PALOCHKA}]*")


def luke_tables(path, v0_counts):
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = [line for line in f.read().split("\n") if line.strip()]
    seen, raw_counts, raw_forms = set(), Counter(), {}
    for line in lines:
        raws = V0_TOKEN.findall(v0_repair_text(line))
        tokens = [t for t in (v0_normalize(r) for r in raws) if v0_valid(t)]
        if not tokens:
            continue
        key = " ".join(tokens)
        if key in seen:          # v0 counted a repeated line once
            continue
        seen.add(key)
        for r in raws:
            raw_counts[r] += 1
            raw_forms.setdefault(v0_normalize(r), set()).add(r)

    counts = Counter()
    for r, n in raw_counts.items():
        counts[v0_normalize(r)] += n
    kept = {w: n for w, n in counts.items() if v0_valid(w)}
    if kept != v0_counts:
        raise Fail("the Luke text does not reproduce the corpus counts of agx_words.tsv")

    glued = []      # (raw, parts, count, rule)
    for raw, n in sorted(raw_counts.items()):
        if not INNER_CAPITAL.search(raw):
            continue
        parts = PART.findall(raw)
        if "".join(parts) != raw or len(parts) != 2:
            raise Fail(f"unexpected capitals in {raw!r}")
        token = v0_normalize(raw)
        if len(raw_forms[token]) != 1 or v0_counts.get(token) != n:
            raise Fail(f"{raw!r} is not the only form of its v0 row")
        glued.append((raw, [v0_normalize(p) for p in parts], n, "G1"))
    g1 = {v0_normalize(raw) for raw, *_ in glued}

    # G2: … + «Ӏиса…». The second word is a form of the name that the text has
    # on its own; the first is a word of the text or the one-letter «э».
    for token, n in sorted(kept.items()):
        cut = token.find(NAME)
        if cut <= 0 or token in g1:
            continue
        first, second = token[:cut], token[cut:]
        if second in kept and (first in kept or len(first) == 1):
            raw = next(iter(raw_forms[token]))
            glued.append((raw, [first, second], n, "G2"))

    short = sorted((w, n) for w, n in counts.items() if not v0_valid(w) and aghul_valid(w))
    return glued, short, sum(kept.values())


# ----------------------------------------------------------------- AgulLang
WITH_LATIN_I = re.compile(rf"[{_CYR}I]+(?:-[{_CYR}I]+)*")


def agullang_tables(path):
    v0_words, whole_words, cells_with_i, cells = set(), set(), 0, 0
    with open(path, encoding="utf-8", newline="") as f:
        for row in csv.reader(f):
            if len(row) < 2:
                continue
            cell = row[1]
            cells += 1
            cells_with_i += "I" in cell
            for t in V0_TOKEN.findall(cell):
                t = v0_normalize(t)
                if v0_valid(t):
                    v0_words.add(t)
            for t in WITH_LATIN_I.findall(cell):
                t = v0_normalize(t)          # «I» → ӏ, as v0 meant to
                if aghul_valid(t):
                    whole_words.add(t)
    others = {ch for ch in "".join(open(path, encoding="utf-8").read()) if ch.isascii() and ch.isalpha()} - {"I"}
    if others:
        raise Fail(f"Agul_dict.csv has Latin letters other than I: {sorted(others)}")
    return sorted(whole_words - v0_words), sorted(v0_words - whole_words), len(v0_words), cells, cells_with_i


# ----------------------------------------------------------------- main
def write_tsv(path, header, rows):
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--upstream", default=DEFAULT_UPSTREAM, help="folder with clean_LukeAgul.txt and Agul_dict.csv")
    ap.add_argument("--source", default=DEFAULT_SOURCE, help="folder with the v0 agx_* files")
    ap.add_argument("--out", default=DEFAULT_OUT, help="where the four tables are written")
    args = ap.parse_args()
    try:
        for name, digest in UPSTREAM_SHA256.items():
            path = os.path.join(args.upstream, name)
            if not os.path.exists(path):
                raise Fail(f"missing {path} (github.com/nstsi/agul at {UPSTREAM_COMMIT[:7]})")
            if sha256(path) != digest:
                raise Fail(f"{name}: SHA-256 differs from the pinned upstream file")
        tsv = os.path.join(args.source, "agx_words.tsv")
        if sha256(tsv) != V0_WORDS_TSV_SHA256:
            raise Fail("agx_words.tsv: SHA-256 differs from the pinned v0 file")
        with open(tsv, encoding="utf-8", newline="") as f:
            v0 = {r["word"]: r for r in csv.DictReader(f, delimiter="\t")}
        v0_counts = {w: int(r["count"]) for w, r in v0.items() if int(r["count"])}

        glued, short, tokens = luke_tables(os.path.join(args.upstream, "clean_LukeAgul.txt"), v0_counts)
        words, pieces, v0_agullang, cells, cells_with_i = agullang_tables(os.path.join(args.upstream, "Agul_dict.csv"))
        if v0_agullang != 3054:
            raise Fail(f"the v0 tokenizer gives {v0_agullang} AgulLang words, v0 recorded 3054")
        missing = [p for p in pieces if p not in v0]
        if missing:
            raise Fail(f"pieces that are not v0 rows: {missing[:5]}")
    except Fail as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    os.makedirs(args.out, exist_ok=True)
    write_tsv(os.path.join(args.out, "luke_glued_tokens.tsv"), ["raw_token", "words", "count", "rule"],
              [(raw, " ".join(parts), n, rule) for raw, parts, n, rule in glued])
    write_tsv(os.path.join(args.out, "luke_short_words.tsv"), ["word", "count"], short)
    write_tsv(os.path.join(args.out, "agullang_palochka_words.tsv"), ["word"], [(w,) for w in words])
    write_tsv(os.path.join(args.out, "agullang_cut_pieces.tsv"), ["piece"], [(p,) for p in pieces])
    print(f"Luke: {tokens} tokens reproduce v0; glued tokens: "
          f"{sum(1 for g in glued if g[3] == 'G1')} G1 + {sum(1 for g in glued if g[3] == 'G2')} G2 "
          f"({sum(g[2] for g in glued)} tokens); short words restored: {short}")
    print(f"AgulLang: {cells} entries, {cells_with_i} with a Latin I; v0 word set {v0_agullang}; "
          f"words read whole and missing from it: {len(words)}; cut pieces in it: {len(pieces)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
