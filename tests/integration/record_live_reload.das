options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``live_reload.apng`` against an
//! **already-running** daslang-live.
//!
//! Workflow (two shells):
//!
//!     # window 1 — host with cwd = the asset dir so the APNG lands there:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/tutorial/live_reload.das
//!
//!     # window 2 — fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_live_reload.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "live_reload.apng"

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
        panic("daslang-live not responding on {BASE_URL} — is it running with live_reload.das?")
    }

    let T_VOLUME = "LIVE_WIN/VOLUME"
    let T_PING   = "LIVE_WIN/PING_BTN"

    var snap = wait_for_render(app, T_VOLUME, 10.0f)
    if (snap == null) {
        panic("{T_VOLUME} never rendered — wrong app running on {BASE_URL}?")
    }
    let p_ping   = widget_center(snap, T_PING)
    let p_volume = widget_center(snap, T_VOLUME)

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 60)))

    //! Pacing rule (LOCKED): `frames` is the app's frame counter (60 fps
    //! under vsync), NOT the recorder's fps. For ~3s readable narrate:
    //!     frames = 180   →  3.0s visible
    //!     sleep  = 3500u →  narrate disappears with ~500ms gap before next
    //! Then ~1500ms result dwell after the action.

    // ---- Stage 1: VOLUME (@live slider, preserved across reload) ----
    post_command(app, "imgui_narrate", JV((
        text = "VOLUME is @live — value preserved across reload.",
        target = T_VOLUME,
        frames = 200
    )))
    move_to(app, p_volume)
    sleep(3500u)
    post_command(app, "imgui_set", JV((target = T_VOLUME, value = 0.65f)))
    sleep(1500u)

    // ---- Stage 2: PING button — ClickState's @live click_count ----
    post_command(app, "imgui_narrate", JV((
        text = "PING_BTN.click_count is @live too.",
        target = T_PING,
        frames = 200
    )))
    move_to(app, p_ping)
    sleep(3500u)
    var ping_events : array<JsonValue?>
    ping_events |> click_at(0, p_ping)
    post_command(app, "imgui_mouse_play", JV((events = ping_events)))
    sleep(1200u)
    var ping_events2 : array<JsonValue?>
    ping_events2 |> click_at(0, p_ping)
    post_command(app, "imgui_mouse_play", JV((events = ping_events2)))
    sleep(1500u)

    // ---- Stage 3: custom [live_command] — bump_counter via curl ----
    post_command(app, "imgui_narrate", JV((
        text = "bump_counter is a user-defined [live_command].",
        target = T_PING,
        frames = 200
    )))
    sleep(3500u)
    post_command(app, "bump_counter", JV((by = 1)))
    sleep(800u)
    post_command(app, "bump_counter", JV((by = 5)))
    sleep(800u)
    post_command(app, "bump_counter", JV((by = 1)))
    sleep(1500u)

    // ---- Stage 4: reset_counter — same surface, different handler ----
    post_command(app, "imgui_narrate", JV((
        text = "reset_counter — same surface, app-defined endpoint.",
        target = T_PING,
        frames = 200
    )))
    sleep(3500u)
    post_command(app, "reset_counter", null)
    sleep(1500u)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
