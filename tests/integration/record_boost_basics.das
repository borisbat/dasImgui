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

//! Driver script: record ``boost_basics.apng`` against an
//! **already-running** daslang-live.
//!
//! Workflow (two shells):
//!
//!     # window 1 — host with cwd = the asset dir so the APNG lands there:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/tutorial/boost_basics.das
//!
//!     # window 2 — fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_boost_basics.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "boost_basics.apng"

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
        panic("daslang-live not responding on {BASE_URL} — is it running with boost_basics.das?")
    }

    //! Targets are path-qualified — the `window(BASICS_WIN, ...)` boost
    //! container pushes its name onto the registry path.
    let T_VOLUME = "BASICS_WIN/VOLUME"
    let T_BUMP   = "BASICS_WIN/BUMP_BTN"

    var snap = wait_for_render(app, T_BUMP, 10.0f)
    if (snap == null) {
        panic("{T_BUMP} never rendered — wrong app running on {BASE_URL}?")
    }
    let p_bump = widget_center(snap, T_BUMP)

    //! Slider drag: 10% to 75% along the slider's bbox width.
    let vol_bb = widget_bbox(snap, T_VOLUME)
    let vol_y  = (vol_bb.y + vol_bb.w) * 0.5f
    let vol_x0 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.10f
    let vol_x1 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.75f

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 30)))

    //! Pacing rule (LOCKED): frames=180 = 3.0s; sleep=3500u = ~500ms gap.

    // ---- Stage 1: slider drag ----
    post_command(app, "imgui_narrate", JV((
        text = "VOLUME is a daslang global emitted by the slider macro.",
        target = T_VOLUME,
        frames = 180
    )))
    sleep(3500u)
    var slider_events : array<JsonValue?>
    slider_events |> drag_along(0, (vol_x0, vol_y), (vol_x1, vol_y), 1400)
    post_command(app, "imgui_mouse_play", JV((events = slider_events)))
    sleep(2500u)

    // ---- Stage 2: click the bump button ----
    post_command(app, "imgui_narrate", JV((
        text = "BUMP_BTN.click_count tracks the bumps.",
        target = T_BUMP,
        frames = 180
    )))
    move_to(app, p_bump)
    sleep(3500u)
    var bump_events : array<JsonValue?>
    bump_events |> click_at(0, p_bump)
    post_command(app, "imgui_mouse_play", JV((events = bump_events)))
    sleep(1200u)
    var bump_events2 : array<JsonValue?>
    bump_events2 |> click_at(0, p_bump)
    post_command(app, "imgui_mouse_play", JV((events = bump_events2)))
    sleep(1500u)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
