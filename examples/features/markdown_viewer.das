options gen2

require imgui/imgui_harness
require imgui/imgui_fonts
require imgui/imgui_markdown_view
require imgui/imgui_theme_daslang
require imgui/imgui_style_builtin
require daslib/stringify

// =============================================================================
// FEATURE: markdown_viewer — typed MD4C model + source-mapped ImGui rendering.
//
// Link activation is reported to the host status line; this probe deliberately
// does not launch a browser. Hover a link to reveal its pre-reserved copy icon.
//
// STANDALONE: daslang.exe modules/dasImgui/examples/features/markdown_viewer.das
// HEADLESS:   daslang.exe modules/dasImgui/examples/features/markdown_viewer.das -- --headless --headless-frames=60
// =============================================================================

var private g_font : ImFont?
var private g_font_sources : array<string>
var private g_doc = MdDocument()
var private g_status = "Hover, activate, or copy a link."

[export]
def init() {
    harness_init("dasImgui Markdown viewer", 1040, 820)
    g_font = load_unicode_ui_font(18.0f, g_font_sources)
    apply_daslang_theme(GetStyle())
    let source = %stringify~# Markdown + Unicode 🎨

This is a source-mapped **Markdown viewer** with *emphasis*, `inline code`, ~~deleted text~~, named [documentation](../docs/editor.md "Editor docs"), and a long autolink https://example.com/文档/naïve/é/terminal-and-editor?mode=full&emoji=👩‍💻#résumé.

> Font fallback, grapheme-safe wrapping, semantic links, and the Markdown model are separate layers.

## Work list

- [x] Parse CommonMark and GFM
- [x] Preserve UTF-8 byte ranges
- [ ] Add selection and keyboard navigation later

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
        with_font(g_font, 18.0f) {
            let result = markdown_view("probe", g_doc)
            if (result.copied_node >= 0) {
                g_status = "Copied: {result.target}"
            } elif (result.activated_node >= 0) {
                g_status = "Open requested: {result.target}"
            }
            separator()
            text_colored((color = float4(0.95f, 0.72f, 0.30f, 1.0f), text = g_status))
        }
    }

    harness_end_frame()
}

[export]
def shutdown() {
    harness_shutdown()
}

[export]
def main() {
    init()
    while (!exit_requested()) {
        update()
    }
    shutdown()
}
