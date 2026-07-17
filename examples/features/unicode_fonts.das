options gen2

require imgui/imgui_harness
require imgui/imgui_theme_daslang
require imgui/imgui_fonts
require strings

// =============================================================================
// FEATURE: unicode_fonts — UTF-8 text, explicit font fallback, and colored glyphs.
//
// Windows Terminal uses DirectWrite font fallback. Dear ImGui does not: every
// fallback face has to be merged into the atlas explicitly. This probe uses the
// bundled JetBrains Mono as its base and merges common platform symbol/CJK
// faces when they are available.
//
// STANDALONE: daslang.exe modules/dasImgui/examples/features/unicode_fonts.das
// HEADLESS:   daslang.exe modules/dasImgui/examples/features/unicode_fonts.das -- --headless --headless-frames=60
// =============================================================================

var private g_font : ImFont?
var private g_loaded_sources : array<string>
var private g_sources_text : string
var private g_has_grinning_face : bool

def private merge_probe_font(path : string; size_px : float) {
    if (merge_font_from_file(path, size_px)) {
        g_loaded_sources |> push(path)
    }
}

def private load_probe_font(size_px : float) : ImFont? {
    // Match this machine's Windows Terminal profile: Consolas is the primary
    // face; DirectWrite supplies missing glyphs there. Other platforms retain
    // dasImgui's bundled JetBrains Mono as the portable base.
    let windows_consolas = "C:/Windows/Fonts/consola.ttf"
    let base = get_running_platform_name() == "windows" && font_file_exists(windows_consolas) ? windows_consolas : daslang_font_ttf_path()
    var font = load_font_from_file(base, size_px)
    if (font != null) {
        g_loaded_sources |> push(base)
    }

    // Symbol/emoji outlines first, then progressively broader language faces.
    // Missing paths are intentionally harmless so the probe stays portable.
    if (get_running_platform_name() == "windows") {
        merge_probe_font("C:/Windows/Fonts/seguisym.ttf", size_px)
        merge_probe_font("C:/Windows/Fonts/seguiemj.ttf", size_px)
        merge_probe_font("C:/Windows/Fonts/NotoSans-Regular.ttf", size_px)
        merge_probe_font("C:/Windows/Fonts/NotoSansJP-Regular.ttf", size_px)
        merge_probe_font("C:/Windows/Fonts/msyh.ttc", size_px)
        merge_probe_font("C:/Windows/Fonts/malgun.ttf", size_px)
        merge_probe_font("C:/Windows/Fonts/NotoSansHebrew-Regular.ttf", size_px)
        merge_probe_font("C:/Windows/Fonts/NotoSansArabic-Regular.ttf", size_px)
    } elif (get_running_platform_name() == "osx") {
        merge_probe_font("/System/Library/Fonts/Apple Symbols.ttf", size_px)
        merge_probe_font("/System/Library/Fonts/Apple Color Emoji.ttc", size_px)
        merge_probe_font("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", size_px)
    } else {
        merge_probe_font("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size_px)
        merge_probe_font("/usr/share/fonts/truetype/noto/NotoSansSymbols2-Regular.ttf", size_px)
        merge_probe_font("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", size_px)
    }
    return font
}

[export]
def init() {
    harness_init("dasImgui Unicode font probe", 1000, 760)
    g_font = load_probe_font(20.0f)
    g_has_grinning_face = font_has_glyph(g_font, 0x1F600u)
    g_sources_text = build_string() $(var writer) {
        for (source in g_loaded_sources) {
            write(writer, "  • {source}\n")
        }
    }
    GetStyle().FontScaleMain = 1.0f
}

[export]
def update() {
    if (!harness_begin_frame()) return
    harness_new_frame()

    SetNextWindowPos(ImVec2(20.0f, 20.0f), ImGuiCond.Always)
    SetNextWindowSize(ImVec2(960.0f, 720.0f), ImGuiCond.Always)
    window(UNICODE_WIN, (text = "Unicode font probe", closable = false,
                         flags = ImGuiWindowFlags.None)) {
        with_font(g_font, 20.0f) {
            text("UTF-8 text with explicit Dear ImGui font fallback")
            separator()

            text("Latin:     déjà vu · Straße · smørrebrød · naïve · ĀČĘ")
            text("Greek:     Ελληνικά · Καλημέρα κόσμε")
            text("Cyrillic:  Русский · Привет, мир")
            text("CJK:       日本語 · 简体中文 · 한국어")
            text("Hebrew:    עברית · שלום עולם  (glyph check; bidi is separate)")
            text("Arabic:    العربية · مرحبا بالعالم  (glyph check; shaping is separate)")
            text("Combining: é / é · Å / Å")

            separator()
            text("Terminal symbols:  ✓  ✗  ⚠  ⓘ  →  ←  •  ◆  ▶  ⏱  ⌁")
            text("Powerline PUA:      prompt     branch")

            text("Tinted glyphs:"); same_line()
            text_colored((color = float4(0.35f, 0.90f, 0.45f, 1.0f), text = "✓ success")); same_line()
            text_colored((color = float4(1.00f, 0.72f, 0.25f, 1.0f), text = "⚠ warning")); same_line()
            text_colored((color = float4(1.00f, 0.35f, 0.35f, 1.0f), text = "✗ error")); same_line()
            text_colored((color = float4(0.45f, 0.75f, 1.00f, 1.0f), text = "ⓘ info"))

            separator()
            text("Supplementary plane: 😀  🚀  🧪  🎨")
            if (g_has_grinning_face) {
                text_colored((color = float4(0.35f, 0.90f, 0.45f, 1.0f), text = "WCHAR32 check: U+1F600 is present in the merged font."))
            } else {
                text_colored((color = float4(1.00f, 0.72f, 0.25f, 1.0f), text = "WCHAR32 check passed; the merged fonts do not provide U+1F600 through stb_truetype."))
            }

            separator()
            text("Merged font sources:")
            text_wrapped((text = g_sources_text))
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
