options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
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
//!     # window 1 -- host with cwd = the asset dir:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/tutorial/narrative_layout_tour.das
//!
//!     # window 2 -- fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_boost_narrative_layout.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "narrative_layout_tour.apng"

//! Reader pacing locked per skills/recording.md.
let NARRATE_FRAMES = 240
let READ_MS    = 5000u
let SETTLE_MS  = 1500u
let TAIL_MS    = 1500u   //! cushion after final narrate so record_stop doesn't cut the last frame

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
        panic("daslang-live not responding on {BASE_URL} -- is it running with narrative_layout_tour.das?")
    }

    var snap = wait_for_render(app, "TOUR_WIN/INTRO", 10.0f)
    if (snap == null) {
        panic("TOUR_WIN/INTRO never rendered -- wrong app on {BASE_URL}?")
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
    //! fps=20: the progress_bar animates every frame and the recording is
    //! 55s long, so 30 fps blew past GitHub's 50 MB warning band. 20 fps
    //! keeps the cursor-tracking smooth enough for readers while cutting
    //! ~30% of file size.
    post_command(app, "record_start", JV((file = OUTPUT, fps = 20, max_seconds = 75)))

    //! Initial cursor placement (synth IO flips `cursor_owned` on first move).
    move_to(app, (450.0f, 360.0f), 600)
    sleep(SETTLE_MS)

    // ---- Stage 1: plain text ----
    move_to(app, p_intro, 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "text() -- one line, telemetry-visible.",
        target = "TOUR_WIN/INTRO",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 2: wrapped text ----
    move_to(app, p_wrap, 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "text_wrapped reflows to the window's right edge.",
        target = "TOUR_WIN/WRAP",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 3: colored / disabled / bullet ----
    move_to(app, p_colored, 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "text_colored + text_disabled -- inline visual variants.",
        target = "TOUR_WIN/COLORED",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)
    move_to(app, p_bullet, 700)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "bullet_text -- marker + text in one call.",
        target = "TOUR_WIN/BULLET_LINE",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 4: label_text (two-string) ----
    move_to(app, p_label, 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "label_text -- label and value side-by-side.",
        target = "TOUR_WIN/LABEL_VERSION",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 5: separator_text ----
    move_to(app, p_septitle, 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "separator_text -- inline section header.",
        target = "TOUR_WIN/SEP_TITLE",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 6: progress_bar (driven by the host) ----
    move_to(app, p_progress, 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "progress_bar -- fraction driven from the host loop.",
        target = "TOUR_WIN/PROG_BAR",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 7: flat tooltip on hover ----
    move_to(app, p_tooltip, 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "set_item_tooltip -- fires when hovering the previous item.",
        target = "TOUR_WIN/HOVER_TIP",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)
    sleep(TAIL_MS)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
