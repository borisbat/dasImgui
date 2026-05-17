options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``imgui_demo_style_editor.apng`` against an
//! **already-running** daslang-live hosting harness_style_editor.das.
//!
//! Workflow (two shells):
//!
//!     # window 1 -- host with cwd = the asset dir so the APNG lands there:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/imgui_demo/harness_style_editor.das
//!
//!     # window 2 -- fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_imgui_demo_style_editor.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "imgui_demo_style_editor.apng"

//! Reader pacing: narrate frames=240 -> 4.0s visible at 60 fps app. Then
//! sleep ~5s lets reader finish + 1s gap before the next action.
let NARRATE_FRAMES   = 240
let READ_MS          = 5000u
let SETTLE_MS        = 1500u
let RESULT_MS        = 2000u

def widget_bbox(var snap : JsonValue?; ident : string) : float4 {
    var b = snap?["globals"]?[ident]?["bbox"]
    return float4(
        b?["x"] ?? 0.0f,
        b?["y"] ?? 0.0f,
        b?["z"] ?? 0.0f,
        b?["w"] ?? 0.0f
    )
}

def widget_center(var snap : JsonValue?; ident : string) : tuple<float; float> {
    let b = widget_bbox(snap, ident)
    return ((b.x + b.z) * 0.5f, (b.y + b.w) * 0.5f)
}

[export]
def main {
    let app = ImguiApp(
        base_url = BASE_URL,
        feature_path = "",
        transport <- live_api_transport(BASE_URL)
    )
    print("[record] connecting to {BASE_URL}\n")
    if (!wait_until_ready(app, 5.0f)) {
        panic("daslang-live not responding on {BASE_URL} -- is it running with harness_style_editor.das?")
    }

    //! Tab IDs live under MAIN_WIN/STYLE_TABS/<tab>; FrameRounding slider lives
    //! directly under MAIN_WIN (Simplified Settings, outside tab_bar).
    let T_WIN        = "MAIN_WIN"
    let T_TABS       = "MAIN_WIN/STYLE_TABS"
    let T_TAB_SIZES  = "MAIN_WIN/STYLE_TABS/STYLE_TAB_SIZES"
    let T_TAB_COLORS = "MAIN_WIN/STYLE_TABS/STYLE_TAB_COLORS"
    let T_TAB_FONTS  = "MAIN_WIN/STYLE_TABS/STYLE_TAB_FONTS"
    let T_TAB_REND   = "MAIN_WIN/STYLE_TABS/STYLE_TAB_RENDERING"
    let T_FR_SLIDER  = "MAIN_WIN/STYLE_FRAME_ROUNDING"

    var snap = wait_for_render(app, T_TABS, 10.0f)
    if (snap == null) {
        panic("{T_TABS} never rendered -- wrong app running on {BASE_URL}?")
    }
    let p_fr_slider  = widget_center(snap, T_FR_SLIDER)
    let p_tab_sizes  = widget_center(snap, T_TAB_SIZES)
    let p_tab_colors = widget_center(snap, T_TAB_COLORS)
    let p_tab_fonts  = widget_center(snap, T_TAB_FONTS)
    let p_tab_rend   = widget_center(snap, T_TAB_REND)

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 55)))

    //! Initial cursor placement (synth IO flips `cursor_owned` on first move).
    move_to(app, (360.0f, 270.0f), 600)
    sleep(SETTLE_MS)

    // ---- Stage 1: introduce the Style Editor window ----
    post_command(app, "imgui_narrate", JV((
        text = "Style Editor -- daslang port of ShowStyleEditor (imgui_demo.cpp:6680).",
        target = T_WIN,
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 2: hover + drag FrameRounding slider ----
    move_to(app, p_fr_slider, 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "FrameRounding slider -- edit_slider_float on style.FrameRounding.",
        target = T_FR_SLIDER,
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)
    //! Drag the slider rightward to demonstrate live style update.
    let drag_to = (p_fr_slider._0 + 80.0f, p_fr_slider._1)
    var drag_events : array<JsonValue?>
    drag_events |> drag_along(0, p_fr_slider, drag_to, 1200)
    post_command(app, "imgui_mouse_play", JV((events = drag_events)))
    sleep(RESULT_MS)

    // ---- Stage 3: click Colors tab ----
    move_to(app, p_tab_colors, 900)
    sleep(SETTLE_MS)
    var colors_events : array<JsonValue?>
    colors_events |> click_at(0, p_tab_colors, 250)
    post_command(app, "imgui_mouse_play", JV((events = colors_events)))
    sleep(RESULT_MS)
    post_command(app, "imgui_narrate", JV((
        text = "Colors tab -- one edit_color_edit4 per ImGuiCol, with_id scopes each row.",
        target = T_TAB_COLORS,
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 4: click Fonts tab ----
    move_to(app, p_tab_fonts, 900)
    sleep(SETTLE_MS)
    var fonts_events : array<JsonValue?>
    fonts_events |> click_at(0, p_tab_fonts, 250)
    post_command(app, "imgui_mouse_play", JV((events = fonts_events)))
    sleep(RESULT_MS)
    post_command(app, "imgui_narrate", JV((
        text = "Fonts tab -- edit_drag_float on io.FontGlobalScale.",
        target = T_TAB_FONTS,
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 5: click Rendering tab ----
    move_to(app, p_tab_rend, 900)
    sleep(SETTLE_MS)
    var rend_events : array<JsonValue?>
    rend_events |> click_at(0, p_tab_rend, 250)
    post_command(app, "imgui_mouse_play", JV((events = rend_events)))
    sleep(RESULT_MS)
    post_command(app, "imgui_narrate", JV((
        text = "Rendering tab -- AA checkboxes + tessellation tolerance sliders.",
        target = T_TAB_REND,
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 6: click back to Sizes ----
    move_to(app, p_tab_sizes, 900)
    sleep(SETTLE_MS)
    var sizes_events : array<JsonValue?>
    sizes_events |> click_at(0, p_tab_sizes, 250)
    post_command(app, "imgui_mouse_play", JV((events = sizes_events)))
    sleep(RESULT_MS)
    post_command(app, "imgui_narrate", JV((
        text = "Sizes tab -- separator_text groups of edit_slider_float sliders.",
        target = T_TAB_SIZES,
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
