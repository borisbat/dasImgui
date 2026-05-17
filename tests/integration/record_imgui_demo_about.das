options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``imgui_demo_about.apng`` against an
//! **already-running** daslang-live hosting the single-scene harness.
//!
//! Workflow (two shells):
//!
//!     # window 1 -- host with cwd = the asset dir so the APNG lands there:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/imgui_demo/harness_about.das
//!
//!     # window 2 -- fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_imgui_demo_about.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "imgui_demo_about.apng"

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
        panic("daslang-live not responding on {BASE_URL} -- is it running with harness_about.das?")
    }

    //! Widget paths are window-prefixed; edit_checkbox + button register
    //! their id= as path leaves.
    let T_WIN    = "ABOUT_WINDOW"
    let T_CB     = "ABOUT_WINDOW/ABOUT_SHOW_CONFIG_INFO_CB"
    let T_COPY   = "ABOUT_WINDOW/BUTTON_COPY"

    var snap = wait_for_render(app, T_CB, 10.0f)
    if (snap == null) {
        panic("{T_CB} never rendered -- wrong app running on {BASE_URL}?")
    }
    let p_cb     = widget_center(snap, T_CB)

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 45)))

    //! Reader pacing: narrate frames=240 -> 4.0s visible at 60 fps app.
    //! READ_MS=5000 lets reader finish + 1s gap before the next action.
    let NARRATE_FRAMES = 240
    let READ_MS    = 5000u
    let SETTLE_MS  = 1500u
    let RESULT_MS  = 2000u

    //! Initial cursor placement (synth IO flips `cursor_owned` on first move).
    move_to(app, (360.0f, 270.0f), 600)
    sleep(SETTLE_MS)

    // ---- Stage 1: title + version ----
    post_command(app, "imgui_narrate", JV((
        text = "Dear ImGui about window -- daslang port of ShowAboutWindow.",
        target = T_WIN,
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 2: toggle config/build dump ----
    move_to(app, p_cb, 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "Tick the checkbox to expand the io/style dump.",
        target = T_CB,
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)
    var cb_events : array<JsonValue?>
    cb_events |> click_at(0, p_cb, 250)
    post_command(app, "imgui_mouse_play", JV((events = cb_events)))
    sleep(RESULT_MS)

    // ---- Stage 3: copy-to-clipboard button (now visible) ----
    var snap2 = wait_for_render(app, T_COPY, 5.0f)
    if (snap2 == null) {
        panic("{T_COPY} never rendered after expand -- about.das port broken?")
    }
    let p_copy = widget_center(snap2, T_COPY)
    move_to(app, p_copy, 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "Copy to clipboard -- log_to_clipboard / log_text / log_finish tee the dump.",
        target = T_COPY,
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)
    var copy_events : array<JsonValue?>
    copy_events |> click_at(0, p_copy, 250)
    post_command(app, "imgui_mouse_play", JV((events = copy_events)))
    sleep(RESULT_MS)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
