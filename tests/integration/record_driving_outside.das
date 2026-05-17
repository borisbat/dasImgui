options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``driving_outside.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_driving_outside.das
//!
//! Every action is performed via L2/L3 live commands (imgui_set /
//! imgui_click / imgui_open / imgui_close) — no mouse moves into widget
//! centers, since the whole point is to demonstrate the "no input device
//! required" programming model.

[export]
def main {
    with_recording_app("examples/tutorial/driving_outside.das",
                       "driving_outside.apng", 60) $(app) {
        //! Every target is path-qualified — the window pushes its name.
        let T_USER   = "DRIVE_WIN/USER"
        let T_SPEED  = "DRIVE_WIN/SPEED"
        let T_PRESET = "DRIVE_WIN/PRESET"
        let T_RUN    = "DRIVE_WIN/RUN_BTN"
        let T_POPUP  = "DRIVE_WIN/STATUS_POPUP"

        var snap = wait_for_render(app, T_USER, 10.0f)
        if (snap == null) {
            panic("{T_USER} never rendered — wrong app running?")
        }

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
    }
}
