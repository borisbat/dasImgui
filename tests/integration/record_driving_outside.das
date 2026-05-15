options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``driving_outside.apng`` against an
//! **already-running** daslang-live. Every action is performed via
//! live commands — no mouse moves into widget centers, since the
//! whole point is to demonstrate the "no input device required"
//! programming model.
//!
//! Workflow (two shells):
//!
//!     # window 1 — host with cwd = the asset dir so the APNG lands there:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/tutorial/driving_outside.das
//!
//!     # window 2 — fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_driving_outside.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "driving_outside.apng"

//! No mouse-driving helpers — this driver intentionally uses only the
//! L2/L3 live-command surface (imgui_set / imgui_click / imgui_open /
//! imgui_close), so there's no need to look up widget centers.

[export]
def main {
    let app = ImguiApp(
        base_url = BASE_URL,
        feature_path = "",
        transport <- live_api_transport(BASE_URL)
    )
    print("[record] connecting to {BASE_URL}\n")
    if (!wait_until_ready(app, 5.0f)) {
        panic("daslang-live not responding on {BASE_URL} — is it running with driving_outside.das?")
    }

    //! Every target is path-qualified — the window pushes its name.
    let T_USER   = "DRIVE_WIN/USER"
    let T_SPEED  = "DRIVE_WIN/SPEED"
    let T_PRESET = "DRIVE_WIN/PRESET"
    let T_RUN    = "DRIVE_WIN/RUN_BTN"
    let T_POPUP  = "DRIVE_WIN/STATUS_POPUP"

    var snap = wait_for_render(app, T_USER, 10.0f)
    if (snap == null) {
        panic("{T_USER} never rendered — wrong app running on {BASE_URL}?")
    }

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 60)))

    //! Pacing rule (LOCKED): `frames` is the app's frame counter (60 fps
    //! under vsync), NOT the recorder's fps. For ~3s readable narrate:
    //!     frames = 180   →  3.0s visible
    //!     sleep  = 3500u →  narrate disappears with ~500ms gap before next
    //! Then ~1500ms result dwell after the action.

    // ---- Stage 1: imgui_set on a text input ----
    post_command(app, "imgui_narrate", JV((
        text = "imgui_set on USER — string value into the input.",
        target = T_USER,
        frames = 200
    )))
    sleep(3500u)
    post_command(app, "imgui_set", JV((target = T_USER, value = "Alice")))
    sleep(1500u)

    // ---- Stage 2: imgui_set on a slider (numeric) ----
    post_command(app, "imgui_narrate", JV((
        text = "imgui_set on SPEED — numeric value (queues pending_value).",
        target = T_SPEED,
        frames = 200
    )))
    sleep(3500u)
    post_command(app, "imgui_set", JV((target = T_SPEED, value = 7)))
    sleep(1500u)

    // ---- Stage 3: imgui_set on a combo (selected index) ----
    post_command(app, "imgui_narrate", JV((
        text = "imgui_set on PRESET — combo by selected index.",
        target = T_PRESET,
        frames = 200
    )))
    sleep(3500u)
    post_command(app, "imgui_set", JV((target = T_PRESET, value = 2)))
    sleep(1500u)

    // ---- Stage 4: imgui_click on a button ----
    post_command(app, "imgui_narrate", JV((
        text = "imgui_click on RUN_BTN — same path the chrome would fire.",
        target = T_RUN,
        frames = 200
    )))
    sleep(3500u)
    post_command(app, "imgui_click", JV((target = T_RUN)))
    sleep(800u)
    post_command(app, "imgui_click", JV((target = T_RUN)))
    sleep(800u)
    post_command(app, "imgui_click", JV((target = T_RUN)))
    sleep(1500u)

    // ---- Stage 5: imgui_open / imgui_close on a popup ----
    post_command(app, "imgui_narrate", JV((
        text = "imgui_open / imgui_close — popup open/close from outside.",
        target = T_RUN,
        frames = 200
    )))
    sleep(3500u)
    post_command(app, "imgui_open", JV((target = T_POPUP)))
    sleep(1700u)
    post_command(app, "imgui_close", JV((target = T_POPUP)))
    sleep(1500u)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
