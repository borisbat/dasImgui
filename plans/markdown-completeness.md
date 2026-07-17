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
| Fenced/indented code | text, info, and language retained | selectable monospace child plus language/info badge | model + live metadata/geometry | complete; syntax highlighting belongs to the shared syntax layer |
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
| Images | destination/title retained; alt flattened to one atomic run | stable colored placeholder, alt fallback, hover/activate/URI copy | model + live geometry/hover | partial: host texture binding and image clipboard formats remain |
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

## Image resource contract

The Markdown layer owns image semantics and layout fallback, not I/O. An image
request is identified by its document revision and image node index and carries
the parsed destination, optional title, and plain-text alt. The host resolves
that request under its own URI, network, cache, and security policy.

A future resolved response supplies an `ImTextureRef`, intrinsic pixel size,
chosen display size, and a resource revision. Unresolved, loading, rejected,
and failed responses all keep the same atomic alt/URI semantics and render the
stable placeholder; resolution must never change source mapping or clipboard
fallback. The display cache keys resolved size and resource revision so a
texture becoming available invalidates only affected image layout.

Plain-text copy of an image is its alt text. Clipboard v2 can additionally
offer `image/png`, `text/markdown`, `text/html`, and `text/uri-list`; those
formats are host/export concerns and do not belong in the text-flow core.

## Completion order

1. Add host texture binding and rich/image clipboard offers to the completed
   atomic placeholder contract.
2. Add hard-break rendering coverage.
3. Close list marker/delimiter fidelity gaps.
4. Freeze Markdown behavior, then extract shared layout and read-only text
   interaction machinery before editor mutation work begins.
