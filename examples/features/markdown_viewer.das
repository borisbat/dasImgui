options gen2
options gc
options persistent_heap

require imgui/imgui_harness
require imgui/imgui_fonts
require imgui/imgui_markdown_view
require imgui/imgui_theme_daslang
require imgui/imgui_style_builtin
require daslib/safe_addr
require daslib/stringify
require math

// =============================================================================
// FEATURE: markdown_viewer — typed MD4C model + source-mapped ImGui rendering.
//
// Link activation is reported to the host status line; this probe deliberately
// does not launch a browser. Drag-select any rendered inline text, then
// right-click the highlight to exercise source/style/screen comment anchors.
//
// STANDALONE: daslang.exe modules/dasImgui/examples/features/markdown_viewer.das
// HEADLESS:   daslang.exe modules/dasImgui/examples/features/markdown_viewer.das -- --headless --headless-frames=60
// =============================================================================

var private g_fonts = FontRoleSet()
var private g_font_sources : array<string>
var private g_doc = MdDocument()
var private g_view = MarkdownViewState()
var private g_status = "Drag to select text; right-click a selection for its comment anchor."
var private g_zoom_percent = 100
var private g_context_source = TextSourceRange(start_byte = -1, end_byte = -1)

def private selection_style_summary(styles : MdSelectionStyles) : string {
    if (styles.all_regular) return "regular"
    var value = ""
    if (styles.has_strong) {
        value = value + (empty(value) ? "strong" : ", strong")
    }
    if (styles.has_emphasis) {
        value = value + (empty(value) ? "emphasis" : ", emphasis")
    }
    if (styles.has_code) {
        value = value + (empty(value) ? "code" : ", code")
    }
    if (styles.has_strikethrough) {
        value = value + (empty(value) ? "strike" : ", strike")
    }
    if (styles.has_links) {
        value = value + (empty(value) ? "links" : ", links")
    }
    if (styles.has_mixed_styles) {
        value = value + (empty(value) ? "mixed" : ", mixed")
    }
    return empty(value) ? "none" : value
}

[export]
def init() {
    harness_init("dasImgui Markdown viewer", 1040, 820)
    g_fonts = load_unicode_font_roles(18.0f, g_font_sources)
    apply_daslang_theme(GetStyle())
    let source = %stringify~# Markdown + Unicode 🎨

This is a source-mapped **Markdown viewer** with *emphasis*, `inline code`, ~~deleted text~~, named [documentation](../docs/editor.md "Editor docs"), and a long autolink https://example.com/文档/naïve/é/terminal-and-editor?mode=full&emoji=👩‍💻#résumé.

The shared plain-text pass also recognizes custom editor://workspace/文档 and WWW.Example.org/Unicode/文档 outside Markdown link syntax.

> Font fallback, grapheme-safe wrapping, semantic links, and the Markdown model are separate layers.

## Work list

- [x] Parse CommonMark and GFM
- [x] Preserve UTF-8 byte ranges
- [x] Source-mapped rich text selection and comment anchors
- [ ] Add keyboard navigation later

## Follow-up: shared text infrastructure

- [ ] Syntax token model independent of Markdown, ImGui, and the future editor
- [ ] Language-aware syntax highlighting for fenced code blocks
- [ ] Reuse the same tokenizer/theme pipeline in the text editor
- [ ] Incremental tokenization for large editable documents

## Table test

| Script | Sample | State |
| :--- | :---: | ---: |
| Cyrillic | Привет | ✓ |
| CJK | 日本語 · 中文 | 🎨 |
| Combining | é / é | ready |

## Code

```das
let greeting = "Привет, 世界 👋"
print("{greeting}\n")
```

Entities decode for display while retaining source bytes: &amp; &copy; &#x1f680;.
%%
    g_doc <- md_parse(source)
    if (!g_doc.ok) {
        g_status = g_doc.error
    }
}

[export]
def update() {
    if (!harness_begin_frame()) return
    harness_new_frame()

    SetNextWindowPos(ImVec2(20.0f, 20.0f), ImGuiCond.Always)
    SetNextWindowSize(ImVec2(1000.0f, 780.0f), ImGuiCond.Always)
    window(MARKDOWN_VIEW_WIN, (text = "Markdown viewer", closable = false,
                               flags = ImGuiWindowFlags.None)) {
        let io & = unsafe(GetIO())
        if (IsWindowHovered(ImGuiHoveredFlags.RootAndChildWindows) && io.KeyCtrl) {
            if (io.MouseWheel > 0.0f) {
                g_zoom_percent = min(g_zoom_percent + 10, 300)
            } elif (io.MouseWheel < 0.0f) {
                g_zoom_percent = max(g_zoom_percent - 10, 50)
            }
        }
        text("Zoom")
        same_line()
        SetNextItemWidth(180.0f)
        if (edit_slider_int(safe_addr(g_zoom_percent),
                (id = "MARKDOWN_ZOOM", text = "##zoom", v_min = 50,
                 v_max = 300, format = "%d%%"))) {
            g_zoom_percent = clamp(((g_zoom_percent + 5) / 10) * 10, 50, 300)
        }
        same_line()
        if (small_button(ZOOM_RESET, (text = "100%"))) {
            g_zoom_percent = 100
        }
        same_line()
        text_disabled("Ctrl+wheel")
        separator()
        with_font(g_fonts.regular, 18.0f) {
            var markdown_style = MarkdownViewStyle(
                fonts = g_fonts,
                zoom = float(g_zoom_percent) / 100.0f)
            let result = markdown_view("probe", g_doc, g_view, markdown_style)
            if (result.copied) {
                g_status = "Copied: {result.target}"
            } elif (result.selection_copied) {
                g_status = "Copied selected display text."
            } elif (result.activated) {
                g_status = "Open requested: {result.target}"
            } elif (result.selection_context_requested) {
                g_context_source = result.selection.source
                g_status = "Comment requested at ({int(result.selection_context_pos.x)}, {int(result.selection_context_pos.y)})"
                SetNextWindowPos(result.selection_context_pos, ImGuiCond.Appearing)
                open_popup("markdown_selection_comment")
            } elif (result.selection_changed && result.selection.active) {
                let s = result.selection
                g_status = "Selected source bytes {s.source.start_byte}..{s.source.end_byte}; {selection_style_summary(s.styles)}; anchor ({int(s.screen_anchor.x)}, {int(s.screen_anchor.y)})"
            } elif (result.selection_changed) {
                g_status = "Selection cleared."
            }
            popup_window(SELECTION_COMMENT_POPUP,
                         (str_id = "markdown_selection_comment",
                          flags = ImGuiWindowFlags.AlwaysAutoResize)) {
                text("Comment anchor")
                separator()
                text("Source bytes {g_context_source.start_byte}..{g_context_source.end_byte}")
                text_wrapped((text = md_source_text(g_doc, g_context_source)))
                if (button(ADD_COMMENT, (text = "Add comment"))) {
                    g_status = "Host accepted comment anchor {g_context_source.start_byte}..{g_context_source.end_byte}"
                    close_current_popup()
                }
            }
            separator()
            text_colored((color = float4(0.95f, 0.72f, 0.30f, 1.0f), text = g_status))
        }
    }

    harness_end_frame()
}

[export]
def shutdown() {
    markdown_view_dispose(g_view)
    harness_shutdown()
}

[export]
def main() {
    init()
    while (!exit_requested()) {
        update()
        harness_maybe_collect_gc()
    }
    shutdown()
}
