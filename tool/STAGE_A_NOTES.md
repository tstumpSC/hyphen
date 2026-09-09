# Task 13 — Stage A notes

Full-corpus Stage A (`--stage-a`, comparing `marks` + `out` + `legacy` + `error`)
was run per dictionary over the complete 9,260,124-record-per-side corpus.

## Result

**`mismatched: 0` on every one of the 9 real dictionaries**, including `de`
and `ca`:

| dict            | compared  | mismatched |
|------------------|-----------|------------|
| local_de_DE      | 1,523,340 | 0 |
| local_de_DE_UTF  | 1,523,340 | 0 |
| local_en_US      | 315,744   | 0 |
| de               | 1,523,340 | 0 |
| en               | 315,744   | 0 |
| hu               | 575,532   | 0 |
| nl               | 1,080,516 | 0 |
| sv               | 937,206   | 0 |
| ca               | 1,218,774 | 0 |

The task brief predicted Stage A would be clean everywhere *except* `de` and
`ca`, where a benign hazard-1 diff was expected. The observed result is
stronger than that: it is clean *everywhere*, including `de` and `ca`. This
is not because hazard 1 failed to fire — it fires, extensively — but because
the Dart port reproduces the C's asymmetry exactly, so a C-vs-Dart Stage A
diff never materialises from it. See below.

## Hazard 1 was confirmed to actually fire, and confirmed to be reproduced byte-for-byte

Hazard 1 is `hyphenate2` writing ASCII `48` where `hyphenate3` writes raw
`NUL` (`0`) at a position a `NOHYPHEN` entry suppresses
(`lib/src/engine.dart:556` vs `:596`, `_applyNohyphen(dict, word, wordSize,
hyphens, _kZero)` vs `_applyNohyphen(dict, word, wordSize, hyphens, 0)`).

I verified directly against `tool/goldens/c.jsonl` (not just inferred from a
clean diff) that this fires on real corpus records — grepping for a raw `0`
value inside a `v3(...)` record's `marks` array, distinguishable from the
ASCII-48 fill value:

```
grep '"dict":"de"' goldens/c.jsonl | grep -P '"params":"v3' \
  | grep -cP '"marks":\[(?:\d+,)*0,'
# => 325

grep '"dict":"ca"' goldens/c.jsonl | grep -P '"params":"v3' \
  | grep -cP '"marks":\[(?:\d+,)*0,'
# => 12330
```

The identical query against `goldens/dart.jsonl` returns **325** and
**12330** respectively — the same counts, and (per the Stage A `mismatched:
0` result) at the same positions for the same words. Example, present
byte-identical on both sides:

```
{"dict":"de","params":"v3(2,3,2,3)","word":"ADGB-Vorsitzender",
 "marks":[48,48,48,0,0,48,50,49,48,50,49,48,50,49,48,48,48],
 "out":["ADGB-Vor","sit","zen","der"],"legacy":"ADGB-Vor=sit=zen=der"}
```

Positions 3 and 4 are raw `0` (hazard 1), not ASCII `48`. Both C and Dart
produce this exact vector.

## Correction to the brief's causal claim: hazard 1 is not confined to `de`/`ca`

The brief's reasoning was: `de` and `ca` are the only corpus dictionaries
with an explicit `NEXTLEVEL` in their own file, and an explicit `NEXTLEVEL`
is "the only situation where hazard 1 can fire." That premise is incomplete.
I ran the same raw-`NUL`-in-`marks` query against every other real
dictionary and it fires there too, in far larger numbers:

| dict             | hazard-1 hits (v3, raw NUL in marks) |
|------------------|---------------------------------------|
| local_de_DE      | 325 |
| local_de_DE_UTF  | 23,735 |
| local_en_US      | 2,450 |
| de               | 325 |
| en               | 2,450 |
| hu               | 163,630 |
| nl               | 33,885 |
| sv               | 11,830 |
| ca               | 12,330 |

Reading `lib/src/dict_loader.dart:253-271` (mirroring `hyphen.c:461-472`)
explains why: when a dictionary's own file has **no** `NEXTLEVEL` keyword,
`hnj_hyphen_load_file` doesn't just load one level — it *synthesises* a
second level and returns *that* as the live dictionary, with the file's real
patterns pushed down to `nextlevel`. The synthesised level's own patterns
are hardcoded:

```dart
loadLine(_ascii("NOHYPHEN ',-\n"), dict[k], hashtab);   // (or the UTF-8
                                                          //  en-dash/quote
                                                          //  variant)
loadLine(_ascii('1-1\n'), dict[k], hashtab);
loadLine(_ascii("1'1\n"), dict[k], hashtab);
```

That `NOHYPHEN ',-` line means **every** dictionary without its own
`NEXTLEVEL` — i.e. every corpus dictionary except `de.dic` and `ca.dic` —
gets a synthesised `NOHYPHEN` suppressing `,`, `'`, `-` (and, for UTF-8
dicts, the en dash / right single quote too), and the returned dictionary's
own `NOHYPHEN` list is exactly what `_applyNohyphen` runs hazard 1 through.
`de` and `ca`, which *do* have an explicit `NEXTLEVEL`, are actually the
*outliers* — they use the real dictionary file's own `NOHYPHEN` line instead
of the synthesised one — not the only two dictionaries where hazard 1 can
fire.

Net effect: hazard 1 fires on every real dictionary in the corpus (all 9),
confirmed by direct measurement, not merely on `de`/`ca` as predicted. In
every case the Dart port reproduces the exact same raw-`NUL` positions as
the C, so it never surfaces as a Stage A (or Stage B) mismatch anywhere.
**The gate result — Stage A clean, Stage B clean, on every dictionary — is
unaffected by this correction; only the brief's narrower explanation of
*why* needed correcting.**

## Hazard 5 (uninitialised reads in `hnj_hyphen_lhmin`'s ligature probe)

Not observed as an explanation for anything, because nothing needed
explaining — Stage A was clean with zero mismatches across all 9 real
dictionaries. This is consistent with the earlier C-vs-C determinism run
(275,676 records, zero mismatches) that first established hazard 5 does not
manifest as non-determinism in the reference build being linked against
here.

## Conclusion

Every Stage A mismatch category the brief anticipated (hazard 1, hazard 5)
was checked for directly against the full corpus. Hazard 5 does not occur.
Hazard 1 does occur, extensively, on every real dictionary — and the port
reproduces it exactly, so it produces zero observable Stage A or Stage B
mismatches. No unexplained Stage A mismatch was found anywhere in the run.
