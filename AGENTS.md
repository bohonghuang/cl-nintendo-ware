# Repository Guidelines

## Project Overview

`cl-nintendo-ware` is a Common Lisp reader for modern NintendoWare C/F sound files used by 3DS, Wii U and Switch: SEQ, WAV, WAR, BNK, WSD, STM, SAR and GRP. Package `cl-nintendo-ware`, nickname `nintendo-ware`. Parse files and event syntax only; do not add sequence execution, audio decoding, playback or synthesizer integration. Nitro/NDS and Wii R-family headers are different formats, not aliases of these readers.

## Architecture & Data Flow

- `read-file` normalizes pathnames, filename strings and binary streams to octet vectors. The generated `embedded-file` reader selects each concrete C/F schema from its own magic and BOM, including embedded files.
- `define-nintendo-ware-file` and `define-nintendo-ware-section` follow the native `cl-nitro` include-based pattern. Modern files locate sections through sized references; do not assume contiguous section order.
- `defbinstruct/me` defines a default LE reader, a deferred `/le` alias and a `/be` reader sharing the original Lisp type. The BE declaration is macroexpanded under this library's own `*endian*`; reader type expansion propagates endian into nested structures and arrays.
- Return binstruct structures directly. No post-parse result models, resource views, hand-built object graphs or manual binary decoding.
- Preserve serial ASDF order. `file.lisp` loads last to compile complete cross-format and recursive readers.

## Key Directories

- `sound/`: platform-neutral sound schemas, references, tables and event declarations.
- `test/`: independent fixture layouts and assertion-based reader regressions. Keep downloaded game assets and temporary smoke scripts outside the repository.

## Development Commands

Use SBCL with Quicklisp initialized. After moving the repository into `local-projects/`, run `(ql:register-local-projects)`.

```bash
# Load/build
sbcl --non-interactive --eval '(ql:quickload :cl-nintendo-ware :silent t)'
# All reader tests
sbcl --non-interactive --eval '(ql:quickload :cl-nintendo-ware :silent t)' \
  --eval '(asdf:test-system :cl-nintendo-ware)'
```

No configured lint command, application executable or playback command. Smoke the actual library, e.g. `(nintendo-ware:read-file :auto #P"/path/to/music.bcseq")`.

## Code Conventions & Common Patterns

- Use lowercase, hyphenated names and two-space Lisp body indentation. Prefer generic names such as `sound-sequence`, `sound-wave-channel` and `sound-archive-sequence-info`, not platform-prefixed layouts with identical definitions.
- Declare binary fields with binstruct. Use `defbinstruct/me` only where C/F layout evidence supports sharing; preserve explicit layouts for packed words whose byte-field order differs. See `ENDIAN.md` and the reference parsers.
- Binary parsing MUST be entirely declarative binstruct layouts. NEVER use handwritten `read-byte`/`read-sequence` decoding, byte-array indexing/slicing/traversal, byte assembly, or a manual byte cursor to interpret fields or events. Padding and validation also belong in binstruct declarations, not byte-array postprocessing.
- `defbinio` is the final code-generation entry point for complete files ONLY, after all schemas. NEVER generate event-, section-, or other leaf-level readers with `defbinio`, or manually invoke leaf readers to traverse an event stream.
- Events MUST be concrete CLOS-dispatchable binstruct types with semantic fields, embedded child events and generated `/partial` layouts. Dispatch uses a declarative `(or (event-type-1) (event-type-2) ...)` union with leading opcode predicates. NEVER expose opcodes, raw event bytes or binary positions to consumers. Resolve flow/track/label targets to event indices inside the parser; consumers such as closynth must not interpret binary data.
- `define-sequence-event` accepts `(name event-bytes)`: `ensure-list` preserves scalar single-byte syntax, e.g. `(wait #x80)`, while `(mod2-phase (#xf0 #xa1))` and longer lists declare multiple fixed tag bytes. Emit one `satisfies`/`eql` field per byte, with no hardcoded extension flag, prefix or separate extension registry. Partial readers validate the supplied first tag and read all remaining tag bytes before the retained parameter fields.
- Follow the specified ME expansion order: default definition, protected BE macroexpansion, deferred LE alias, reader dispatch method. Do not replace this with runtime endian parameters or separate Lisp types. Recursive ME types need a forward reader-dispatch declaration; see `sound/sequence.lisp`.
- Keep schema parameter lists at most three arguments. Reuse `reference-to`, `bounded`, `file-span`, `reference-target` and `sized-reference-target`; relative addressing must use native `pointer`. Validate tags, counts and spans before allocating or following targets. File readers and `defbinio` declarations take no extra schema arguments or external `limit`.
- `%...` slots are parser bookkeeping; `$...` position anchors participate in native relative addressing. Keep bounds local. Parsing is synchronous; do not add mutable global parse state. `*endian*` is compile-time expansion context, not runtime parser state.
- Container BOM and payload endian are distinct. CSEQ and Wii U events are BE; Switch FSEQ events are LE. File declarations select the event-stream layout; consumers receive the same semantic event types without endian or opcode dispatch.
- Keep absent optional data/null references as `NIL`, preserve raw resource IDs and non-event payloads, and never open external archive paths automatically. Use `fail-file`/`invalid-file` for invalid structures, unknown events and targets that are not event boundaries.
- Defaults must match specialized array/string types. Use typed empty octet arrays, not untyped `#()`, and base-string defaults for base-string fields.
- Reader only: do not add writer hooks, writer correctness promises or writer tests. Keep declarations and pointer information compatible with binstruct so future writer work remains possible. Test fixture emitters only construct independent input bytes.

## Important Files

- `cl-nintendo-ware.asd`: dependencies, serial schema order and test operation.
- `binary.lisp`: native alias and ME declaration macros; `section.lisp` / `container.lisp`: reusable headers and declaration macros.
- `common.lisp`: references, bounds, BOM, headers, flags and embedded-file dispatch.
- `sound/sequence.lisp`: shared opcode syntax and event endian selection. `file.lisp`: parameterless generated readers and public input dispatch.
- `README.md`: API and verification scope. `ENDIAN.md` / `BCSEQ.md`: platform and format evidence.

## Runtime/Tooling Preferences

Use SBCL, ASDF and Quicklisp with `alexandria`, `binstruct`, `parsonic` and `flexi-streams`. Let ASDF manage FASLs; do not add another build system or edit sibling dependencies without an explicit need. Follow native patterns in `cl-nitro` and `pokerom`. Keep temporary downloads and smoke scripts under `/mnt/d/tmp/` and remove throwaway scripts afterward.

## Testing & QA

Tests use Common Lisp assertions, not a separate framework. `test/sequence.lisp` declares independent fixtures and typed sequence-event cases, embedded partials and byte-target-to-index conversion; `test/formats.lisp` covers waves/banks; `test/archives.lisp` covers SAR/GRP/WSD/STM. `test/endian-fixtures.lisp` provides independent BE input layouts; `test/endian-readers.lisp` covers shared semantic event types, nested prefixes, C/F profiles and payload endian exceptions through complete files only.

Check real fields and reference targets, never generated source or constructor wiring. Relevant boundaries: truncation, bad BOM/tags, null and out-of-range references, array counts, VLQ limits, nested prefixes, embedded files with independent BOMs and version-dependent layouts. Keep tests deterministic and network-independent.

Exercise changed readers on actual or synthetic binary input in addition to regressions. The typed-event reader passed 63 public BCSEQ files with 401,232 top-level events and index conversion; this includes statically unreachable events, not just a control-flow walk. A smoke run used actual `closynth:event-emit` methods on parsed note/tempo types without binary access; this is dispatch evidence, not playback support. Citric's `guts.bcseq` contains a target inside another instruction and fails event-boundary validation. Other platforms/formats primarily have synthetic verification; do not claim universal game compatibility or audio playback from parser evidence.

## External References

These third-party projects are format/implementation references, not runtime dependencies:

- [Citric Composer](https://github.com/Gota7/Citric-Composer): C/F containers, sound-format layouts, version branches and endian handling. Its [format specifications](https://gota7.github.io/Citric-Composer/specs/common.html) document shared headers and references.
- [GotaSequenceLib](https://github.com/Gota7/GotaSequenceLib): SEQ opcodes, extended commands and random/variable/time prefixes, including omitted child-command parameters.
- [GotaSoundIO](https://github.com/Gota7/GotaSoundIO): supplementary NintendoWare sound-format implementation for cross-checking layouts.
- [DualRip](https://github.com/TetraSsky/DualRip): independent Python reference for archive, wave-sound-data and bank layouts and reference semantics.

Sample provenance, not a parser implementation: [OoT3D-Custom-Sequences](https://github.com/Kewlan/OoT3D-Custom-Sequences) supplies the public BCSEQ verification corpus described above.
