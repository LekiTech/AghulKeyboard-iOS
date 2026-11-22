# Pinned upstream files

Unmodified copies, used by `AghulLayoutTests` and `scripts/analyze_layout.py`,
and kept for attribution.

| File | Repository | Path | Commit |
|---|---|---|---|
| `rus-3-rows.yaml` | https://github.com/Agisight/ios-system-keyboard | `layout/rus/rus-3-rows.yaml` | `86e000a966d5d5aa5282617d5f6d90c69890e8db` (2026-11-11) |
| `rus-longpress.yaml` | https://github.com/Agisight/ios-system-keyboard | `layout/rus/rus-longpress.yaml` | same |
| `agx_key_default.json` | https://github.com/Agisight/rf-keyboard-corpora | `data/agx/Ali_Kuzhuget/keyboard/agx_key_default.json` | `cd7a94ee8318b1abb7690b93755242fd73aaf1b5` (2026-11-11) |
| `agx_key_mapping.json` | same | `data/agx/Ali_Kuzhuget/mapping/agx_key_mapping.json` | same |
| `agx_key_mapping_ext.json` | same | `data/agx/Ali_Kuzhuget/mapping/agx_key_mapping_ext.json` | same |
| `agx_monocorpus_freq.csv` | same | `data/agx/Ali_Kuzhuget/frequencies/agx_monocorpus_freq.csv` | same |

Both repositories are MIT licensed: `LICENSE-ios-system-keyboard`
(Copyright (c) 2025 Agisight) and `LICENSE-rf-keyboard-corpora`
(Copyright (c) 2025 Agisight (Ali Kuzhuget)).

What the Aghul keyboard takes from them:

- `rus-3-rows.yaml`, `rus-longpress.yaml`: a transcription of the Russian
  iOS keyboard (letter rows, number and symbol pages, symbol alternates),
  the baseline the Aghul layout departs from by two keys.
- `agx_monocorpus_freq.csv`: letter counts of Aghul web text (FineWeb-2,
  collected 2025-08-03), with the two-character letters of the alphabet
  counted as letters. It gives the order of the long-press options and is
  an independent check of the frequencies measured from the keyboard's own
  dictionary. Its query reads I, 1, l and | as the palochka.
- `agx_key_mapping_ext.json`: long presses for the Russian keyboard, the
  two-character letters under their first letter (and «дж» under «ж»).
  The digraph callouts follow it, except that the doubled letters (кк пп
  тт чч) are left to a double tap and «дж» sits under «д».
- `agx_key_default.json`: kept as the record that upstream has no Aghul
  layout. The file is a stub: `"layout_name": "Aghul (customized)"`,
  `"keys": []`, `"long_press": []`.
- `agx_key_mapping.json`: one entry, «Ь: Ӏ» (the palochka, U+04C0, under a
  long press on ь). It is the "A0" candidate of `docs/LAYOUT.md` and is not
  taken: the palochka has its own key.

Not available upstream: an Aghul layout. At the commits above
`ios-system-keyboard` has no `layout/agx`.
