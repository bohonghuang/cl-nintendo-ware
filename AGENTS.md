# Repository Guidelines

## Project Overview

`cl-nintendo-ware` is a Common Lisp reader for modern NintendoWare C/F sound files used by 3DS, Wii U and Switch: SEQ, WAV, WAR, BNK, WSD, STM, SAR and GRP. Package `cl-nintendo-ware`, nickname `nintendo-ware`. Parse files and event syntax only; do not add sequence execution, audio decoding, playback or synthesizer integration. Nitro/NDS and Wii R-family headers are different formats, not aliases of these readers.

## Architecture & Data Flow

- `read-file` follows cl-nitro: dispatch on exported file symbols (`xseq`, `xwav`, `xwar`, `xbnk`, `xwsd`, `xstm`, `xsar`, `xgrp`) and input types. Pathnames open binary streams; filename strings become pathnames; octet vectors become in-memory streams. Each format's stream method invokes its generated `read-x...` reader. Complete and embedded files read their own magic and BOM; input streams must support seeking. Do not restore keyword/magic aliases or `:auto` dispatch.
- `define-nintendo-ware-file` and `define-nintendo-ware-section` follow Nitro: name/options then fields, no lambda list. Concrete files, sections and their bodies take no arguments. Public containers use inline body, a native end-position marker before padding, and declarative remaining padding. Keep this future-writer structure; do not implement size backpatching or promise writer correctness. Bodies recover their header from the native file anchor. Modern files still locate sections through sized references, not assumed contiguous order.
- `defbinstruct/me` defines default LE and shared-type BE readers and registers reader/writer symbol-property expanders. Only header, SEQ track and SEEK row retain forced-LE aliases. Protected BE expansion uses this library's `*endian*`; inline container arguments must explicitly select the corresponding body parser rather than relying on schema-type dispatch.
- Return binstruct structures directly. The explicit cl-nitro-style `xsar-files` helper returns a simple-vector of `(name . data)` conses, with `xsar-file-name`/`xsar-file-data` as car/cdr accessors. Otherwise do not add post-parse result models, resource views, hand-built object graphs or manual binary decoding.
- Preserve serial ASDF order. `file.lisp` loads before `section.lisp`; `sound/sound.lisp` loads before every concrete sound module. Complete-file readers are generated in their owning modules after their schemas.
- XSAR extracts raw octet vectors declaratively from sized references; never dispatch embedded readers, inspect child magic/BOM or validate child events while reading XSAR. Callers explicitly select `read-file` types afterward. Keep file IDs including absent/external entries (NIL data); zero-length data stays an octet vector. Names are optional resource aliases, not synthesized filenames; later named resources win in sounds/banks/wave-archives/groups order. WAR/GRP embedded parsing is unchanged.
- Public API ergonomics take priority over exporting implementation details. Keep `package.lisp` concise like cl-nitro: expose `read-file`, file symbols and genuinely useful file-level extraction tools (`xseq-events`, `xwar-waves`, `xsar-files` and its `xsar-file-name`/`xsar-file-data` aliases). Do not export a section, field accessor, event type, constructor or macro merely to make it accessible; prefer requiring users to explicitly use `nintendo-ware::` for internals. Do not add trivial wrappers or an extractor for every field/file just to expand the public surface. Declare all public exports in `package.lisp`'s `defpackage`, never in modules or macro expansions. Keep internal field definitions unchanged; all library references in tests use `nintendo-ware::`. Reloading the package declaration after the library must not produce package-variance warnings.

## Key Directories

- `sound/`: platform-neutral sound schemas, references, tables and event declarations.
- `test/`: independent fixture layouts, assertion-based reader regressions and the explicitly retained real archive `test/data/mset.bcsar`. Keep other downloaded game assets and temporary smoke scripts outside the repository.

## Development Commands

Use SBCL with Quicklisp initialized. After moving the repository into `local-projects/`, run `(ql:register-local-projects)`.

```bash
# Load/build
sbcl --non-interactive --eval '(ql:quickload :cl-nintendo-ware :silent t)'
# All reader tests
sbcl --non-interactive --eval '(ql:quickload :cl-nintendo-ware :silent t)' \
  --eval '(asdf:test-system :cl-nintendo-ware)'
```

No configured lint command, application executable or playback command. Smoke the actual library, e.g. `(nintendo-ware:read-file 'nintendo-ware:xseq #P"/path/to/music.bcseq")`.

## Code Conventions & Common Patterns

- Use lowercase, hyphenated names and two-space Lisp body indentation. Sound modules and their types/functions/macros use `x` plus the last three magic characters: `xseq`, `xwav`, `xwar`, `xbnk`, `xwsd`, `xstm`, `xsar`, `xgrp`. Prefer shared names such as `xseq`, `xwav-channel` and `xsar-sequence-info`, not separate C/F layouts with identical definitions.
- Treat Alexandria as part of the standard library: directly `:use #:alexandria` in library and test packages, and use its exported symbols without package prefixes (e.g. `symbolicate`, `ensure-list`, `with-gensyms`, `curry`).
- Define optional-parameter masks as format/record-specific `defbinstruct/me` flag sets using binstruct's native bitfields and `(:alignment 4)` for numeric 32-bit words. Pass declaration options through unchanged; do not infer field widths or reorder fields in ME macros. Switch bits MUST use `(boolean bit)` and names ending in `-p`; read each semantic optional field declaratively in ascending bit order. Do not reintroduce a generic mask/value-array type or decode switches with `logbitp`.
- Declare binary fields with binstruct. Use `defbinstruct/me` only where C/F layout evidence supports sharing; preserve explicit layouts for packed words whose byte-field order differs. See `ENDIAN.md` and the reference parsers.
- Binary parsing MUST be entirely declarative binstruct layouts. NEVER use handwritten `read-byte`/`read-sequence` decoding, byte-array indexing/slicing/traversal, byte assembly, or a manual byte cursor to interpret fields or events. Padding and validation also belong in binstruct declarations, not byte-array postprocessing.
- Explicit VLQ exception: copy the proven cl-smf/cl-nitro implementation unchanged. Use its original `vlq`, `%vlq`, `%vlq-integer` and `integer-%vlq` names; this shared primitive is exempt from module prefixes. Preserve its declarative continuation-byte array, integer conversion functions and alias mapping, including the reverse conversion; these are not permission to add file writers. Do not replace it with fixed first/second/third/fourth groups or impose an unsupported four-byte/28-bit limit. Its byte-array integer conversion is an explicit exception to the preceding rule.
- Higher-order parsers such as `inline` are permitted ONLY in file/section container binary types. NEVER use them in concrete records, references, tables or events. Nullable references use native `or`, `pointer`, `values` and typed identity `map` layouts, not custom reference type expanders.
- Container context comes from native positional aliases. Preserve file/section magic matching, opcode discrimination, reference tags and BOM/layout dispatch. Do not add file/section size-consistency, span or overlap checks. File fields must restore their owning file's native position anchor before following section references, including after mixed-endian embedded files.
- `defbinio` is the final code-generation entry point for complete files ONLY, after all schemas. NEVER generate event-, section-, or other leaf-level readers with `defbinio`, or manually invoke leaf readers to traverse an event stream.
- Events MUST be concrete CLOS-dispatchable binstruct types with semantic fields, embedded child events and generated `/partial` layouts. Dispatch uses a declarative `(or (event-type-1) (event-type-2) ...)` union with leading opcode predicates. NEVER expose opcodes, raw event bytes or binary positions to consumers. Resolve flow/track/label targets to event indices inside the parser; consumers such as closynth must not interpret binary data.
- `define-xseq-event` accepts `(name event-bytes)`: `ensure-list` preserves scalar single-byte syntax, e.g. `(wait #x80)`, while `(mod2-phase (#xf0 #xa1))` and longer lists declare multiple fixed tag bytes. Emit one `satisfies`/`eql` field per byte, with no hardcoded extension flag, prefix or separate extension registry. Partial readers validate the supplied first tag and read all remaining tag bytes before the retained parameter fields.
- ME expansion order is default definition, protected BE expansion and symbol-property reader/writer registration; recursive records may register before their body declaration. Complete files have one reader; their container reads BOM and chooses an inline BE/default body parser. Never generate complete-file endian variants or pre-read embedded BOMs. Do not add per-type endian defmethod or runtime endian parameters.
- Keep schema parameter lists at most three arguments. Use native pointer instead of explicit peek wherever possible; the current library has no explicit peek forms. Prefer cross-structure `$` position anchors to propagated position parameters. Native `$` supports deferred targets; use native values grouping when a following field requires the pointed value immediately. Ordinary records, tables and references must not propagate section-end offsets. Do not wrap embedded readers in sized-reference-length checks. File readers and defbinio take no external limit.
- Pass native pointer bases as symbols such as `$info-start`, never `(progn $info-start)`. Give nested tables record-specific `$...-start` anchors so child tables cannot overwrite parent bases. Wrap pointer in native `values` whenever it is not the outermost field type, including union branches and array elements. Keep native aliases for container context and forward addressing. CWSD item sends/envelope offsets are relative to the parameter flags; note offsets are relative to the note including its wave index. SAR project-info uses reference tag `#x220b`, not `#x2107`.
- Only layouts that genuinely require the remaining bytes may use the zero-width `nintendo-ware-section-tail-size`, stored as `%size`. Obtain the current `%position` locally and use `(+ %position %size)` when an absolute end is required. Current uses are the uncounted SEQ event stream and SEEK trailing padding. NEVER inject tail bookkeeping into all section bodies or reintroduce generic bounded-layout wrappers.
- `%...` slots are parser bookkeeping; `$...` position anchors participate in native relative addressing. Parsing is synchronous; do not add mutable global parse state. `*endian*` is compile-time expansion context, not runtime parser state.
- Container BOM and payload endian are distinct. CSEQ and Wii U events are BE; Switch FSEQ events are LE. File declarations select the event-stream layout; consumers receive the same semantic event types without endian or opcode dispatch.
- Keep absent optional data/null references as `NIL`, preserve every resource-ID bit through the native `nintendo-ware-sound-resource-id` layout and `nintendo-ware-sound-resource-id-value`, retain non-event payloads, and never open external archive paths automatically. Use `fail-file`/`invalid-file` for invalid structures, unknown events and targets that are not event boundaries.
- Defaults must match specialized array/string types. Use typed empty octet arrays, not untyped `#()`, and base-string defaults for base-string fields.
- Reader only: do not add writer hooks, writer correctness promises or writer tests. Keep declarations and pointer information compatible with binstruct so future writer work remains possible. Test fixture emitters only construct independent input bytes.

## Important Files

- `cl-nintendo-ware.asd`: dependencies, serial schema order and test operation.
- `binary.lisp`: native alias and ME declaration macros; `section.lisp` / `file.lisp`: reusable headers and declaration macros.
- `common.lisp`: input dispatch, errors and prefixed references. `file.lisp`: file headers and containers. `sound/sound.lisp`: shared `nintendo-ware-sound-` layouts.
- `sound/xseq.lisp`: shared opcode syntax and event endian selection. Concrete sound modules generate their parameterless readers; public input dispatch lives in `common.lisp`.
- `README.md`: API and verification scope. `ENDIAN.md` / `BCSEQ.md`: platform and format evidence.

## Runtime/Tooling Preferences

Use SBCL, ASDF and Quicklisp with `alexandria`, `binstruct`, `parsonic` and `flexi-streams`. Let ASDF manage FASLs; do not add another build system or edit sibling dependencies without an explicit need. Follow native patterns in `cl-nitro` and `pokerom`. Keep temporary downloads and smoke scripts under `/mnt/d/tmp/` and remove throwaway scripts afterward.

## Testing & QA

Tests use Common Lisp assertions, not a separate framework. `test/sequence.lisp` declares independent fixtures and typed sequence-event cases, embedded partials and byte-target-to-index conversion; `test/formats.lisp` covers waves/banks; `test/archives.lisp` covers SAR/GRP/WSD/STM. `test/endian-fixtures.lisp` provides independent BE input layouts; `test/endian-readers.lisp` covers shared semantic event types, nested prefixes, C/F profiles and payload endian exceptions through complete files only.

Check real fields and reference targets, never generated source or constructor wiring. Relevant boundaries: truncation, bad BOM/tags, null and out-of-range references, array counts, VLQ limits, nested prefixes, embedded files with independent BOMs and version-dependent layouts. Keep tests deterministic and network-independent.

Exercise changed readers on actual or synthetic binary input in addition to regressions. The typed-event reader passed 63 public BCSEQ files with 401,232 top-level events and index conversion; this includes statically unreachable events, not just a control-flow walk. A smoke run used actual `closynth:event-emit` methods on parsed note/tempo types without binary access; this is dispatch evidence, not playback support. Citric's `guts.bcseq` contains a target inside another instruction and fails event-boundary validation. Other platforms/formats primarily have synthetic verification; do not claim universal game compatibility or audio playback from parser evidence.

The `pmee` repository's original `mset.bcsar` is retained at `test/data/mset.bcsar` and exercised by `test/pmee.lisp` in the default ASDF test operation, without networking or an external checkout. The test extracts `(name . raw-data)` entries through `xsar-files`, then explicitly reads every SEQ/WSD/BNK/WAR to retain full real-asset verification including WAV data. XSAR itself never parses these children. See README for the exact fingerprint and independent DualRip comparisons. Keep synthetic coverage of selective parsing, optional names, absent/external/empty data, WSD offsets and project-info tags.

## External References

These third-party projects are format/implementation references, not runtime dependencies:

- [Citric Composer](https://github.com/Gota7/Citric-Composer): C/F containers, sound-format layouts, version branches and endian handling. Its [format specifications](https://gota7.github.io/Citric-Composer/specs/common.html) document shared headers and references.
- [GotaSequenceLib](https://github.com/Gota7/GotaSequenceLib): SEQ opcodes, extended commands and random/variable/time prefixes, including omitted child-command parameters.
- [GotaSoundIO](https://github.com/Gota7/GotaSoundIO): supplementary NintendoWare sound-format implementation for cross-checking layouts.
- [DualRip](https://github.com/TetraSsky/DualRip): independent Python reference for archive, wave-sound-data and bank layouts and reference semantics.

Sample provenance, not a parser implementation: [OoT3D-Custom-Sequences](https://github.com/Kewlan/OoT3D-Custom-Sequences) supplies the public BCSEQ verification corpus described above.
