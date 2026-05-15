options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _no_imgui_legacy = true

require imgui public
require imgui/imgui_lint
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``narrative_layout_tour.apng`` against an
//! **already-running** daslang-live hosting
//! ``examples/tutorial/narrative_layout_tour.das``.
//!
//! Walks four boost-v2 families in one window:
//!   1. Narrative widgets (text / text_wrapped / text_colored / text_disabled
//!      / bullet_text / label_text)
//!   2. Layout primitives (separator_text / dummy via spacing fan-out)
//!   3. Display widgets (progress_bar)
//!   4. Flat-form tooltips (set_item_tooltip)
//!
//! Workflow (two shells):
//!
//!     # window 1 — host with cwd = the asset dir:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/tutorial/narrative_layout_tour.das
//!
//!     # window 2 — fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_boost_narrative_layout.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "narrative_layout_tour.apng"

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
        panic("daslang-live not responding on {BASE_URL} — is it running with narrative_layout_tour.das?")
    }

    var snap = wait_for_render(app, "TOUR_WIN/INTRO", 10.0f)
    if (snap == null) {
        panic("TOUR_WIN/INTRO never rendered — wrong app on {BASE_URL}?")
    }

    let p_intro    = widget_center(snap, "TOUR_WIN/INTRO")
    let p_wrap     = widget_center(snap, "TOUR_WIN/WRAP")
    let p_colored  = widget_center(snap, "TOUR_WIN/COLORED")
    let p_bullet   = widget_center(snap, "TOUR_WIN/BULLET_LINE")
    let p_label    = widget_center(snap, "TOUR_WIN/LABEL_VERSION")
    let p_septitle = widget_center(snap, "TOUR_WIN/SEP_TITLE")
    let p_progress = widget_center(snap, "TOUR_WIN/PROG_BAR")
    let p_tooltip  = widget_center(snap, "TOUR_WIN/HOVER_TIP")

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 120)))

    //! Locked pacing (per feedback_imgui_narrate_frames_vs_recorder_fps.md):
    //! frames=180 → ~3.0s narrate visibility @ 60 fps app-side;
    //! sleep=3500u → narrate clears with ~500ms gap; 1500-2500u dwell after.

    // ---- Stage 1: plain text ----
    post_command(app, "imgui_narrate", JV((
        text = "Plain text: one line, no wrap, telemetry-visible.",
        target = "TOUR_WIN/INTRO",
        frames = 180
    )))
    move_to(app, p_intro)
    sleep(3500u)

    // ---- Stage 2: wrapped text ----
    post_command(app, "imgui_narrate", JV((
        text = "text_wrapped reflows to the window's edge.",
        target = "TOUR_WIN/WRAP",
        frames = 180
    )))
    move_to(app, p_wrap)
    sleep(3500u)

    // ---- Stage 3: colored / disabled / bullet ----
    post_command(app, "imgui_narrate", JV((
        text = "text_colored, text_disabled, bullet_text — visual variants.",
        target = "TOUR_WIN/COLORED",
        frames = 180
    )))
    move_to(app, p_colored)
    sleep(2000u)
    move_to(app, p_bullet)
    sleep(2000u)

    // ---- Stage 4: label_text (two-string) ----
    post_command(app, "imgui_narrate", JV((
        text = "label_text shows a label and a value side-by-side.",
        target = "TOUR_WIN/LABEL_VERSION",
        frames = 180
    )))
    move_to(app, p_label)
    sleep(3500u)

    // ---- Stage 5: separator_text ----
    post_command(app, "imgui_narrate", JV((
        text = "separator_text draws an inline section header.",
        target = "TOUR_WIN/SEP_TITLE",
        frames = 180
    )))
    move_to(app, p_septitle)
    sleep(3500u)

    // ---- Stage 6: progress_bar (driven) ----
    post_command(app, "imgui_narrate", JV((
        text = "progress_bar — fraction is driven from the live host.",
        target = "TOUR_WIN/PROG_BAR",
        frames = 180
    )))
    move_to(app, p_progress)
    sleep(3500u)

    // ---- Stage 7: flat tooltip on hover ----
    post_command(app, "imgui_narrate", JV((
        text = "Hover the button — set_item_tooltip fires.",
        target = "TOUR_WIN/HOVER_TIP",
        frames = 180
    )))
    move_to(app, p_tooltip)
    sleep(2500u)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
