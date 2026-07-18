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
| Fenced/indented code | text, info, and language retained | selectable monospace child; language/info retained for future syntax services but not shown as document text | model + live metadata/geometry | complete; syntax highlighting belongs to the shared syntax layer |
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
| Images | destination/title retained; alt flattened to one atomic run | stable placeholder or host-bound texture, alt fallback, hover/activate/URI copy | model + binding lifecycle + live resolve/unresolve | partial: image/rich clipboard formats remain |
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

## View style ownership

The host owns Markdown presentation policy. `FontRoleSet` selects the prose,
emphasis, and monospace faces plus their base pixel size. `MarkdownTypography`
contains relative heading, inline-code, and fenced-code scales.
`MarkdownViewStyle` contains those values along with colors, spacing, padding,
and the per-view zoom. None of these require a user-facing preferences screen.

```das
var style = MarkdownViewStyle(
    fonts = app_fonts,
    typography = MarkdownTypography(
        inline_code_scale = 0.84f,
        code_block_scale = 0.90f,
        heading1_scale = 1.50f),
    zoom = document_zoom)
let result <- markdown_view("document", document, view_state, style)
```

Typography ratios participate in retained layout keys. A host override changes
measurement, wrapping, hit-testing, selection geometry, and painting together;
it is not a draw-only font transform.

## Image resource contract

The Markdown layer owns image semantics and layout fallback, not I/O. An image
request is identified by its document revision and image node index and carries
the parsed destination, optional title, and plain-text alt. The host resolves
that request under its own URI, network, cache, and security policy.

`MarkdownImageBinding` is that response: it supplies a backend texture ID,
display size at 100% document zoom, UVs, tint, and host resource revision. The
viewer scales display geometry with Markdown zoom while texture pixels and UVs
remain unchanged. Hosts can obtain
the retained ID from an `ImTextureRef` through `image_texture_id`, then bind,
replace, or unbind by document revision and image node. Repeating an identical
binding is a cache no-op. Unresolved, loading, rejected, and failed responses
all keep the same atomic alt/URI semantics and render the stable placeholder;
resolution never changes source mapping or clipboard fallback. Each affected
inline layout keys its binding revision and resolved size; unrelated blocks
remain cached.

Plain-text copy of an image is its alt text. Clipboard v2 can additionally
offer `image/png`, `text/markdown`, `text/html`, and `text/uri-list`; those
formats are host/export concerns and do not belong in the text-flow core.

## Completion order

1. Add rich/image clipboard offers to the completed placeholder/texture
   binding contract.
2. Add hard-break rendering coverage.
3. Close list marker/delimiter fidelity gaps.
4. Freeze Markdown behavior, then extract shared layout and read-only text
   interaction machinery before editor mutation work begins.
