# Reference harness

Throwaway tooling for the C-to-Dart port. Not published; see `.pubignore`.

`reference_c/` is the vendored Hunspell/Hyphen C source that this package
shipped through 0.3.1. It is kept solely so the golden corpus can be
regenerated. It is not compiled into the package.

## Usage

`tool/` is a separate Dart package from the one at the repo root. Resolve
its own dependencies first — skipping this step is why a root-level
`dart analyze` can otherwise report dozens of spurious `undefined_function`
errors here that mean nothing:

    cd tool && dart pub get

Then, from `tool/`:

    ./build_reference.sh          # build the C as a loadable dylib
    ./fetch_corpus.sh             # download dictionaries + word lists
    dart run gen_goldens.dart     # corpus through C     -> goldens/c.jsonl
    dart run run_dart_corpus.dart # corpus through Dart  -> goldens/dart.jsonl
    dart run compare.dart goldens/c.jsonl goldens/dart.jsonl

## Corpus sources and licenses

Word lists are hunspell *spelling* dictionaries from
https://github.com/LibreOffice/dictionaries — note these are distinct from
the `hyph_*.dic` hyphenation pattern files, despite sharing the extension.

Nothing fetched here is redistributed; `corpus/` is gitignored.

| Language | Word list | License |
|---|---|---|
| de | `de/de_DE_frami.dic` | GPLv2 / GPLv3 |
| en | `en/en_US.dic` | see repo `en/` README |
| hu | `hu_HU/hu_HU.dic` | see repo `hu_HU/` README |
| nl | `nl_NL/nl_NL.dic` | see repo `nl_NL/` README |
| sv | `sv_SE/dictionaries/sv_SE.dic` | see repo `sv_SE/` LICENSE |
| ca | `ca/dictionaries/ca.dic` | see repo `ca/` LICENSES |
