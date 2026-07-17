# Text Components Architecture

Status: active design note

This note records the shared foundation for text-heavy dasImgui components. It
is deliberately broader than the Markdown viewer: Markdown is the first useful
consumer and test bed, not the owner of the text architecture.

## Endgame

Build reusable foundations for:

- a read-only Markdown viewer;
- a source/text editor and, later, a Markdown editor;
- a terminal component;
- language-aware code views and editors;
- semantic inline UI such as diagnostics, color swatches, URI actions, and
  live shader texture previews.

Every component has two parts:

1. A view-independent core owns UTF-8 text, source mapping, semantics, state,
   and operations.
2. A dasImgui counterpart owns measurement, layout, interaction, drawing, and
   screen-space geometry.

The core must not contain ImGui pointers, fonts, textures, or platform window
state. UI objects are resolved from stable semantic IDs by the view layer.

## Shared stack

```text
UTF-8 source + revision
        |
graphemes, lines, source ranges
        |
lexical tokens / semantic tokens / diagnostics
        |
inline adornments and inlays
        |
view-independent selection, caret, and edit operations
        |
layout fragments with source mapping
        |
dasImgui rendering, hit testing, popups, and editing
```

Markdown parsing adapts its typed tree and inline runs into this stack. It must
not become a dependency of the editor, terminal, syntax, or adornment cores.

## Settled contracts

### Text and source positions

- All public source offsets are UTF-8 byte offsets.
- Carets and wrapping never split a grapheme cluster.
- Display text may differ from source text. For example, an entity can display
  as one glyph while mapping to the complete `&...;` source token.
- A selection exposes both displayed text for clipboard copy and the original
  source range for persistence, comments, diagnostics, and edits.
- A document revision invalidates cached layout and any selection whose source
  positions cannot be remapped safely.

### Selection

The public selection query includes:

- original source byte range;
- display text on demand;
- `MdSelectionStyles`, a bitfield containing `all_regular`, `has_strong`,
  `has_emphasis`, `has_code`, `has_strikethrough`, `has_links`, and
  `has_mixed_styles`;
- exact visible screen bounds;
- a focus-caret screen anchor;
- a separate right-click screen position for context UI.

Screen coordinates belong only to the view result. Persistent annotations use
source ranges and document identity/revision, never pixels.

### Inline controls and adornments

Inline UI reserves geometry during layout whether it is currently visible or
not. Hovering, showing, hiding, or updating the control must not reflow text.
Fixed-position controls register their interaction rectangle without mutating
ImGui's layout cursor.

The URI copy button is the first simple inline adornment and establishes this
rule. It is not a special-case architecture for URIs.

### Clipboard

Clipboard access comes from the platform-neutral `daslib/clipboard` API. Text
crossing the OS boundary is UTF-8. Components do not call backend-specific
ImGui clipboard functions directly.

## Syntax services

Syntax support is independent of Markdown and of any particular editor.

The initial view-independent contract should provide concepts equivalent to:

- `TextToken`: source range, lexical kind, semantic role, and optional language
  payload;
- `TextDiagnostic`: source range, severity, message ID, and related locations;
- `TextAdornment`: source anchor or range, placement, reserved size, kind, and
  stable payload ID;
- a language/provider interface that can tokenize a complete document first
  and incrementally update a changed range later;
- a theme mapping semantic roles to UI styles without baking colors or fonts
  into tokens.

Markdown fenced code will be the first read-only syntax consumer. The same
tokens and theme pipeline must then work unchanged in the editable code view.

## Semantic inlays and live previews

A shader editor is a representative endgame consumer. Given:

```text
tex2D(albedo, uv)
```

semantic analysis can emit an adornment anchored after the expression. The
adornment contains a stable preview/resource ID and reserved display size, not
an ImGui texture handle. The editor view resolves that ID to a small live
thumbnail:

```text
tex2D(albedo, uv) [thumbnail]
```

Expected behavior:

- the thumbnail has zero source width and selection skips over it;
- its reserved geometry remains stable while texture contents update;
- hover can show a larger live preview;
- click can pin/open an inspector;
- changing the texture does not retokenize or relayout text unless the
  adornment's declared size changes;
- removing or moving the expression removes or remaps the adornment through
  the document revision/edit mapping.

The same mechanism covers color literals, breakpoints, diagnostics, test
results, URI actions, terminal annotations, and editor code lenses.

## Current implementation

- Unicode font roles, fallback, zoom, and colored emoji overlays.
- View-independent grapheme grouping, URI recognition, wrapping, styled
  measurement, layout fragments, and grapheme-safe hit testing.
- Typed MD4C Markdown model with display-to-source mapping.
- Cached Markdown layout and explicit lifecycle/disposal.
- Headings, paragraphs, lists, quotes, tables, inline code, fenced code, links,
  plain-text URIs, and link copy controls.
- Source-mapped rich selection across inline blocks and fenced code.
- Selection highlighting, screen anchors, right-click context requests, and
  UTF-8 clipboard copy.

## Roadmap

### Markdown viewer completion

- Add keyboard caret movement and shift-selection.
- Add word/line selection gestures and selection autoscroll.
- Decide how list markers and table separators participate in display copy.
- Add shared syntax highlighting to fenced code once the syntax service exists.

## Deterministic live interaction tests

Interactive text tests are event-driven.  Elapsed time and frame counts never
define success.  A timeout may exist only as a deadlock/crash guard around a
semantic wait.

The Markdown viewer exposes live commands for state, fragment geometry,
selection clearing, and controlled zoom.  Its view state carries monotonic
render, hover, selection, commit, copy, and context revisions.  A test follows
an explicit input/acknowledgement handshake:

1. Resolve a current text fragment to screen geometry.
2. Move the pointer and wait for that exact node/fragment hover identity.
3. Press and wait for `selection_dragging` plus a newer selection revision.
4. Move and wait for a newer focus/selection revision and source range.
5. Release and wait for `selection_dragging == false` plus a newer commit
   revision.
6. For clipboard shortcuts, wait for modifier/key state, a newer copy
   revision, and exact UTF-8 clipboard contents when the desktop provides a
   system clipboard.
7. For context actions, wait for button state, a newer context revision, the
   source-mapped anchor, and the popup/action's observed UI state.
8. For wheel input, wait for the registered ImGui window's observed scroll
   value to change in the requested direction.

This same contract should be reused by the editor and terminal.  Those views
will add document/edit revisions, caret revisions, visible source ranges, and
terminal buffer revisions rather than introducing sleeps or frame delays.

### Shared syntax core

- Define token, diagnostic, provider, theme-role, and revision contracts.
- Start with full-document tokenization and deterministic tests.
- Add incremental invalidation by changed byte/line range.
- Keep language parsers optional and provider-driven.

### Adornment core

- Define before/after/overlay/line-widget placement.
- Define caret, selection, clipboard, accessibility, and hit-testing behavior.
- Add stable payload IDs and a view-side resolver registry.
- Exercise with URI actions, color swatches, and a shader texture-preview
  prototype.

### Editor

- Choose the editable text store and line index.
- Add transactions, undo/redo, multi-selection, indentation, and IME.
- Reuse shared syntax, diagnostics, adornments, layout, and clipboard services.
- Keep editor operations independent of dasImgui rendering.

### Terminal

- Separate terminal buffer/emulation state from rendering.
- Reuse graphemes, font roles, selection, clipboard, URI detection, and
  adornments where terminal semantics permit it.

## Performance and lifecycle rules

- Parsing, tokenization, and layout are revision-cached; stable frames do not
  rebuild them.
- Per-frame rendering must not create retained garbage.
- Explicit deletion releases retained arrays and strings during shutdown or
  revision replacement so GC remains an infrequent safety net.
- Texture contents and hover state do not invalidate text layout.
- Fast tests use deterministic fake font metrics; headless ImGui tests cover
  interaction and geometry; visual probes cover fonts, emoji, tables, and live
  adornments.

## Open design questions

- Editable storage: piece table, rope, gap buffer, or a hybrid line store.
- How edit deltas remap selections, diagnostics, and adornment anchors.
- Full Unicode word and line breaking beyond the current UI-focused grapheme
  implementation.
- Bidirectional text and shaping boundaries.
- Language-provider discovery and lifetime.
- Accessibility representation for zero-width interactive adornments.
- Rich clipboard formats later; UTF-8 plain text remains the required baseline.

## Decision log

- 2026-07-17: Markdown established as the first consumer, not the shared core.
- 2026-07-17: UTF-8 byte offsets and grapheme-safe carets are the source-position
  contract.
- 2026-07-17: Selection exposes original source, semantic-style bitfields, and
  transient screen geometry.
- 2026-07-17: Inline controls reserve stable geometry and may not mutate text
  layout when visibility changes.
- 2026-07-17: Syntax services and semantic adornments are editor-independent.
- 2026-07-17: Live shader texture previews are view-resolved semantic inlays,
  not bytes inserted into source text.
- 2026-07-17: Interactive tests wait for observable event revisions and UI
  state changes; timeouts are deadlock guards only, never test semantics.
