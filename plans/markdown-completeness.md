# Markdown viewer completeness

This matrix is the gate before extracting the shared layout/interaction layer
or starting a full editor. It distinguishes parser recognition, the
view-independent model, rendering, and regression coverage so a feature is not
called complete merely because MD4C emitted a node for it.

Status meanings:

- **complete**: modeled, rendered with intended semantics, source-mapped, and
  covered by a relevant test.
- **partial**: useful behavior exists, but visible semantics or coverage is
  missing.
- **policy**: deliberately constrained behavior rather than an implementation
  accident.
- **future**: outside the CommonMark/GFM viewer baseline.

## Block elements

| Element | Parser/model | Renderer | Tests | Status / remaining work |
|---|---|---|---|---|
| Document, paragraphs | typed tree and source unions | wrapped inline flow | model + live viewer | complete |
| ATX/setext headings | level retained | scaled heading role | model + live viewer | complete |
| Block quotes | nested children retained | indented with quote rule | model + smoke | complete |
| Unordered/ordered lists | tightness, start, task state retained | nested lists and task glyphs | model + smoke | partial: preserve ordered delimiter and marker fidelity |
| Thematic breaks | typed node | separator | smoke | complete |
| Fenced/indented code | text, info, and language retained | selectable monospace child | model + live viewer | partial: expose language/info; syntax highlighting later |
| GFM tables | sections, rows, columns, and alignment retained | bordered table with per-line cell alignment | model + live geometry/hit test | complete |
| Raw HTML blocks | opt-in typed nodes | literal text only | parser option test | policy: source-mapped literal; never execute as HTML |

## Inline elements

| Element | Parser/model | Renderer | Tests | Status / remaining work |
|---|---|---|---|---|
| Text and Unicode | exact UTF-8 ranges | fallback fonts and grapheme flow | core + live viewer | complete |
| Emphasis/strong | semantic run flags | font/color roles | model + selection | complete |
| Inline code | semantic run flag | monospace/background | selection + live viewer | complete |
| GFM strikethrough | semantic run flag | strike rule | model + selection | complete |
| Links | destination/title/autolink retained | hover, activate, URI copy | model + live interaction | partial: expose link title as optional tooltip |
| Plain-text URIs | shared detector and synthetic semantic run | same link behavior | core + model + live interaction | complete |
| Images | destination/title/alt subtree retained | alt text currently behaves like a link | model only | partial: explicit placeholder plus host resolver contract |
| Entities/nulls | source token plus transformed display | displayed glyph remains source-mapped | model | complete |
| Soft breaks | typed leaf | normalized to a wrapping space | model | complete |
| Hard breaks | typed leaf | forced flow line break | model/core | add direct rendering regression |
| Inline raw HTML | opt-in typed leaves | literal text in inline flow | parser option test | policy: source-mapped literal; never execute as HTML |

## Extensions outside the baseline

MD4C can identify LaTeX math, wiki links, and underline spans, but the current
public parse options do not enable them. They remain future opt-in extensions,
not silent promises of the CommonMark/GFM viewer.

HTML-to-dasImgui is a separate future project. It would require an explicit
safe subset, UI node model, style/layout policy, event model, resource policy,
and security boundary. Raw HTML inside Markdown must not become its accidental
entry point.

## Completion order

1. Surface fenced-code language/info without coupling it to syntax services.
2. Define image placeholder and host-provided resource resolution.
3. Add link-title and hard-break rendering coverage.
4. Close list marker/delimiter fidelity gaps.
5. Freeze Markdown behavior, then extract shared layout and read-only text
   interaction machinery before editor mutation work begins.
