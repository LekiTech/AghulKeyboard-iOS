#!/usr/bin/env python3
"""Letter statistics of Aghul and a model comparison of layout candidates.

Python 3 standard library only. Reads the shipped words artifact
(AghulKeyboardExtension/aghul_words.sqlite); the corpus count of a word is
its base_score // 10 (the v0 score is 10 × count + word lists). Writes
docs/layout/analysis.json and prints the same numbers.

    python3 -I scripts/analyze_layout.py [--agisight FILE]

  --agisight FILE  agx_monocorpus_freq.csv of Agisight/rf-keyboard-corpora,
                   an independent letter count of Aghul web text (default: the
                   pinned copy in Tests/AghulCoreTests/Fixtures/agisight).

Everything here is a MODEL of typing, not a measurement of people:

  * a word is typed letter by letter, no suggestion is picked;
  * a letter with its own key costs one tap; a letter without one costs one
    long press on its base key; a long-press option that yields two letters
    («кӀ») counts as one long press;
  * time = taps × t + long presses × (t + delay), with the keyboard's default
    long-press delay of 0.3 s and two tap rates t (0.25 s and 0.18 s);
  * two thumbs: a key belongs to the thumb of its half of the keyboard, and a
    thumb travels in a straight line from the previous key it pressed in the
    same word. Key centres are those of General Keyboard's native grid on a
    402 pt wide iPhone (content width 395 pt, row pitch 54 pt).
"""

import argparse
import csv
import json
import os
import sqlite3
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORDS = os.path.join(REPO, "AghulKeyboard", "AghulKeyboardExtension", "aghul_words.sqlite")
OUT = os.path.join(REPO, "docs", "layout", "analysis.json")
AGISIGHT = os.path.join(REPO, "Tests", "AghulCoreTests", "Fixtures", "agisight", "agx_monocorpus_freq.csv")

P = "ӏ"   # ӏ U+04CF, the palochka of the dictionary rows (the key shows Ӏ U+04C0)
# The nineteen two-character letters of the alphabet of 1990 (Гъ Гь ГӀ Дж Кк
# Къ Кь КӀ Пп ПӀ Тт ТӀ Уь Хъ Хь ХӀ ЦӀ Чч ЧӀ); the palochka is a letter of
# its own as well («Ӏу», «яӀар»), counted as such when no г к п т х ц ч
# stands before it.
DIGRAPHS = ["гъ", "гь", "г" + P, "дж", "кк", "къ", "кь", "к" + P, "пп", "п" + P, "тт", "т" + P, "уь",
            "хъ", "хь", "х" + P, "ц" + P, "чч", "ч" + P]
# Doubled consonants: the four that are letters, and the commonest others.
GEMINATES = ["тт", "кк", "пп", "чч", "лл", "сс"]
VOWELS = "аеёиоуыэюя"
SCREEN = 402.0            # pt, iPhone 18 Pro and the other 6.3" iPhones
SMALL_SCREEN = 375.0      # pt, the narrowest supported iPhones
PAD, INSET, PITCH = 3.5, 3.0, 54.0
LONG_PRESS_DELAY = 0.3    # s, KeyboardSettings.CalloutDelay.normal
TAP_RATES = {"0.25 s per tap": 0.25, "0.18 s per tap": 0.18}

RUSSIAN = ["йцукенгшщзх", "фывапролджэ", "ячсмитьбю"]
PALOCHKA_DIGRAPHS = {d: d[0] for d in DIGRAPHS if d[1] == P}
HARD_DIGRAPHS = {"гъ": "г", "къ": "к", "хъ": "х"}
PALOCHKA_BASES = "гкптхцч"

# name → letter rows, {letter: base key} for letters reached by long press,
#        {two-letter long-press option: base key} used by the model typist
CANDIDATES = {
    "A0": {
        "title": "Russian iOS keyboard, Ӏ and ъ under ь (Agisight agx_key_mapping.json)",
        "rows": RUSSIAN,
        "long_press": {"ё": "е", "ъ": "ь", P: "ь"},
        "digraph_options": {},
    },
    "A": {
        "title": "Russian iOS layout, digraphs on long press under their first letter "
                 "(Agisight agx_key_mapping_ext.json)",
        "rows": RUSSIAN,
        "long_press": {"ё": "е", "ъ": "ь", P: "ь"},
        "digraph_options": {**HARD_DIGRAPHS, **PALOCHKA_DIGRAPHS},
    },
    "B1": {
        "title": "ъ on щ's key, Ӏ on ы's key (the Dargwa and Tabasaran arrangement; chosen)",
        "rows": ["йцукенгшъзх", "ф" + P + "вапролджэ", "ячсмитьбю"],
        "long_press": {"ё": "е", "щ": "ш", "ы": P},
        "digraph_options": {},
    },
    "B2": {
        "title": "Ӏ on щ's key, ъ on ы's key (B1 mirrored)",
        "rows": ["йцукенгш" + P + "зх", "фъвапролджэ", "ячсмитьбю"],
        "long_press": {"ё": "е", "щ": "ш", "ы": "ъ"},
        "digraph_options": {},
    },
    "B3": {
        "title": "Ӏ on ы's key, ъ on э's key, щ kept (the Lak arrangement)",
        "rows": ["йцукенгшщзх", "ф" + P + "вапролджъ", "ячсмитьбю"],
        "long_press": {"ё": "е", "ы": P, "э": "ъ"},
        "digraph_options": {},
    },
    "C": {
        "title": "Russian layout plus ъ and Ӏ as 12th keys of the two upper rows",
        "rows": ["йцукенгшщзхъ", "фывапролджэ" + P, "ячсмитьбю"],
        "long_press": {"ё": "е"},
        "digraph_options": {},
    },
    "D": {
        "title": "B1 with ъ and ь exchanged (ь next to х and г, ъ in the bottom row)",
        "rows": ["йцукенгшьзх", "ф" + P + "вапролджэ", "ячсмитъбю"],
        "long_press": {"ё": "е", "щ": "ш", "ы": P},
        "digraph_options": {},
    },
}


def load():
    con = sqlite3.connect(f"file:{WORDS}?mode=ro", uri=True)
    rows = [(w, s // 10) for w, s in con.execute("SELECT word, base_score FROM words") if s >= 10]
    meta = dict(con.execute("SELECT key, value FROM meta"))
    con.close()
    return rows, meta


def units(word):
    """The word as alphabet letters: the nineteen two-character letters are one each."""
    out, i = [], 0
    while i < len(word):
        if word[i:i + 2] in DIGRAPHS:
            out.append(word[i:i + 2])
            i += 2
        else:
            out.append(word[i])
            i += 1
    return out


def pct(n, total):
    return round(100.0 * n / total, 3) if total else 0.0


def show(text):
    """Dictionary form → what the reader sees (Ӏ U+04C0)."""
    return text.replace(P, "Ӏ")


# ----------------------------------------------------------------- statistics
def statistics(rows):
    chars, letters, pairs, lengths = Counter(), Counter(), Counter(), Counter()
    before = {s: Counter() for s in ("ъ", "ь", P)}
    sequences = Counter()
    examples = {ch: Counter() for ch in "щэыёою"}
    lone_palochka = 0
    tokens = words_with = 0
    special = set("ъь" + P)
    for word, n in rows:
        tokens += n
        lengths[len(word)] += n
        words_with += n if special & set(word) else 0
        for ch in word:
            if ch != "-":
                chars[ch] += n
            if ch in examples:
                examples[ch][word] += n
        for u in units(word):
            if u != "-":
                letters[u] += n
        for a, b in zip(word, word[1:]):
            if a != "-" and b != "-":
                pairs[a + b] += n
        for i, ch in enumerate(word):
            if ch in before:
                before[ch][word[i - 1] if i else "^"] += n
            if ch == P and (i == 0 or word[i - 1] not in PALOCHKA_BASES):
                lone_palochka += n
        for seq in GEMINATES:
            sequences[seq] += n * word.count(seq)
    total_chars, total_letters = sum(chars.values()), sum(letters.values())
    order = [ch for ch, _ in chars.most_common()]

    def sign(ch):
        return {
            "percent_of_characters": pct(chars[ch], total_chars),
            "rank_among_characters": order.index(ch) + 1,
            "per_100_words": round(100.0 * chars[ch] / tokens, 1),
            "after_percent": {show(k): pct(v, chars[ch]) for k, v in before[ch].most_common(8)},
        }

    return {
        "word_types": len(rows),
        "word_tokens": tokens,
        "characters": total_chars,
        "mean_word_length": round(sum(k * v for k, v in lengths.items()) / tokens, 2),
        "character_percent": {show(ch): pct(n, total_chars) for ch, n in chars.most_common()},
        "alphabet_letter_percent": {show(u): pct(n, total_letters) for u, n in letters.most_common()},
        "digraph_percent_of_letters": {show(d): pct(letters[d], total_letters) for d in
                                       sorted(DIGRAPHS, key=lambda d: -letters[d])},
        "digraphs_together_percent_of_letters": pct(sum(letters[d] for d in DIGRAPHS), total_letters),
        "words_with_ъ_ь_or_palochka_percent": pct(words_with, tokens),
        "hard_sign": sign("ъ"),
        "soft_sign": sign("ь"),
        "palochka": sign(P),
        "palochka_as_a_letter_of_its_own": {
            "percent_of_palochkas": pct(lone_palochka, chars[P]),
            "per_100_words": round(100.0 * lone_palochka / tokens, 1),
            "at_the_start_of_a_word_per_100_words": round(100.0 * before[P]["^"] / tokens, 1)},
        "doubled_consonants_per_100_words": {s: round(100.0 * sequences[s] / tokens, 2) for s in GEMINATES},
        "rare_letters_percent_of_characters": {ch: pct(chars[ch], total_chars) for ch in "щыёоюэцж"},
        "rare_letters_per_100_words": {ch: round(100.0 * chars[ch] / tokens, 2) for ch in "щыёоюэцж"},
        "most_frequent_words_with": {ch: dict(c.most_common(12)) for ch, c in examples.items()},
        "top_character_pairs_percent": {show(p): pct(n, sum(pairs.values())) for p, n in pairs.most_common(40)},
    }


def agisight(path):
    """The independent letter count of Agisight/rf-keyboard-corpora (web text, FineWeb-2)."""
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8", newline="") as f:
        rows = [(r["letter"].lower().replace("Ӏ".lower(), P), float(r["percent"])) for r in csv.DictReader(f)]
    table = dict(rows)

    def total(sign_char):
        return round(sum(v for k, v in table.items() if sign_char in k), 3)

    return {
        "note": "percent of alphabet letters, the two-character letters counted as letters; web text "
                "(FineWeb-2), collected 2025-08-03; its query reads I, 1, l and | as the palochka",
        "letter_percent": {show(k): v for k, v in rows},
        "every_ъ_percent": total("ъ"),
        "every_ь_percent": total("ь"),
        "palochka_in_digraphs_percent": round(sum(v for k, v in table.items() if P in k and k != P), 3),
        "lone_palochka_row_percent": table.get(P),
        "щ_ы_ё_о_ю_э_percent": {ch: table.get(ch) for ch in "щыёоюэ"},
    }


# ----------------------------------------------------------------- the typing model
def geometry(rows, screen):
    """Key centres (pt) of the native grid: equal cells in every row; the
    third row has shift and backspace cells around its letters."""
    content = screen - 2 * PAD
    centres = {}
    for r, row in enumerate(rows):
        cells = len(row) + (2 if r == 2 else 0)
        for i, ch in enumerate(row):
            column = i + (1 if r == 2 else 0)
            centres[ch] = (PAD + (column + 0.5) * content / cells, r * PITCH)
    return centres


def key_width(row_length, screen):
    return round((screen - 2 * PAD) / row_length - 2 * INSET, 2)


def keystrokes(word, cand):
    """[(key, is_long_press)] for one word; hyphens are skipped."""
    on_keys = set("".join(cand["rows"]))
    out, i = [], 0
    while i < len(word):
        ch = word[i]
        if ch == "-":
            i += 1
            continue
        pair = word[i:i + 2]
        # A letter without a key that a two-letter option produces together
        # with its base letter: one long press for both.
        if pair in cand["digraph_options"] and pair[1] not in on_keys:
            out.append((cand["digraph_options"][pair], True))
            i += 2
            continue
        if ch in on_keys:
            out.append((ch, False))
        else:
            out.append((cand["long_press"][ch], True))
        i += 1
    return out


def evaluate(rows, cand):
    centres = geometry(cand["rows"], SCREEN)
    taps = long_presses = tokens = chars = words_with_lp = 0
    travel = same_thumb = transitions = 0.0
    held = Counter()
    for word, n in rows:
        strokes = keystrokes(word, cand)
        lp = sum(1 for _, is_held in strokes if is_held)
        tokens += n
        chars += n * sum(1 for ch in word if ch != "-")
        taps += n * (len(strokes) - lp)
        long_presses += n * lp
        words_with_lp += n if lp else 0
        last = {}
        previous_thumb = None
        for key, is_held in strokes:
            held[key] += n if is_held else 0
            x, y = centres[key]
            thumb = "left" if x < SCREEN / 2 else "right"
            if thumb in last:
                px, py = last[thumb]
                travel += n * ((x - px) ** 2 + (y - py) ** 2) ** 0.5
            if previous_thumb is not None:
                transitions += n
                same_thumb += n if previous_thumb == thumb else 0
            last[thumb] = (x, y)
            previous_thumb = thumb
    letters_lp = 100.0 * long_presses / tokens
    widest = max(map(len, cand["rows"][:2]))
    return {
        "title": cand["title"],
        "rows": [show(r) for r in cand["rows"]],
        "keys_per_row": [len(r) for r in cand["rows"]],
        "narrowest_letter_key_pt": {f"{int(SCREEN)} pt screen": key_width(widest, SCREEN),
                                    f"{int(SMALL_SCREEN)} pt screen": key_width(widest, SMALL_SCREEN)},
        "key_presses_per_word": round((taps + long_presses) / tokens, 3),
        "taps_per_word": round(taps / tokens, 3),
        "long_presses_per_100_words": round(letters_lp, 2),
        "long_presses_per_100_characters": round(100.0 * long_presses / chars, 3),
        "long_presses_by_key_per_100_words": {show(k): round(100.0 * v / tokens, 2)
                                              for k, v in held.most_common() if v},
        "words_needing_a_long_press_percent": pct(words_with_lp, tokens),
        "thumb_travel_pt_per_character": round(travel / chars, 2),
        "same_thumb_transitions_percent": pct(same_thumb, transitions),
        "seconds_per_100_words": {
            name: round(100.0 * (taps * t + long_presses * (t + LONG_PRESS_DELAY)) / tokens, 1)
            for name, t in TAP_RATES.items()},
        "letters_moved_from_the_russian_layout": sorted(
            ch for ch in "".join(RUSSIAN)
            if geometry(RUSSIAN, SCREEN)[ch] != centres.get(ch)),
        "letters_without_a_key": sorted(show(k) for k in cand["long_press"]),
    }


def digraph_paths(cand):
    on_keys = set("".join(cand["rows"]))
    centres = geometry(cand["rows"], SCREEN)
    out = {}
    for d in DIGRAPHS:
        if all(ch in on_keys for ch in d):
            (x1, y1), (x2, y2) = centres[d[0]], centres[d[1]]
            thumbs = ["left" if x < SCREEN / 2 else "right" for x in (x1, x2)]
            out[show(d)] = (f"2 taps, {'alternating thumbs' if thumbs[0] != thumbs[1] else 'same thumb'}, "
                            f"{round(((x1 - x2) ** 2 + (y1 - y2) ** 2) ** 0.5)} pt apart")
        elif d in cand["digraph_options"]:
            out[show(d)] = f"long press on {d[0]}"
        else:
            out[show(d)] = f"tap {d[0]}, long press on {cand['long_press'][d[1]]}"
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--agisight", default=AGISIGHT, help="agx_monocorpus_freq.csv of Agisight/rf-keyboard-corpora")
    args = ap.parse_args()
    rows, meta = load()
    report = {
        "source": {"artifact": "aghul_words.sqlite", "content_version": meta.get("content_version"),
                   "cleanup_version": meta.get("cleanup_version"),
                   "note": "token-weighted; corpus count of a word = base_score // 10; "
                           "words known only from a word list (count 0) are left out. The running text is "
                           "one book, the Gospel of Luke (about 18,100 tokens); one-letter words "
                           "(«э», «е», «я») are not rows and are not counted"},
        "statistics": statistics(rows),
        "agisight_letter_count": agisight(args.agisight),
        "model": {"screen_pt": SCREEN, "long_press_delay_s": LONG_PRESS_DELAY, "tap_rates_s": TAP_RATES,
                  "note": "model-based estimates, not measured typing speed"},
        "candidates": {},
    }
    for name, cand in CANDIDATES.items():
        result = evaluate(rows, cand)
        result["digraph_entry"] = digraph_paths(cand)
        report["candidates"][name] = result
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(json.dumps(report, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
