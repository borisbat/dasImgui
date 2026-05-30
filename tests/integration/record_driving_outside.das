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
//! Every action is performed via L2/L3 live commands (imgui_force_set /
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

        // ---- Stage 1: imgui_force_set on a text input ----
        say(app, "imgui_force_set on USER — string value into the input.", T_USER)
        post_command(app, "imgui_force_set", JV((target = T_USER, value = "Alice")))
        sleep(1500u)

        // ---- Stage 2: imgui_force_set on a slider (numeric) ----
        say(app, "imgui_force_set on SPEED — numeric value (queues pending_value).", T_SPEED)
        post_command(app, "imgui_force_set", JV((target = T_SPEED, value = 7)))
        sleep(1500u)

        // ---- Stage 3: imgui_force_set on a combo (selected index) ----
        say(app, "imgui_force_set on PRESET — combo by selected index.", T_PRESET)
        post_command(app, "imgui_force_set", JV((target = T_PRESET, value = 2)))
        sleep(1500u)

        // ---- Stage 4: imgui_click on a button ----
        say(app, "imgui_click on RUN_BTN — same path the chrome would fire.", T_RUN)
        post_command(app, "imgui_click", JV((target = T_RUN)))
        sleep(800u)
        post_command(app, "imgui_click", JV((target = T_RUN)))
        sleep(800u)
        post_command(app, "imgui_click", JV((target = T_RUN)))
        sleep(1500u)

        // ---- Stage 5: imgui_open / imgui_close on a popup ----
        say(app, "imgui_open / imgui_close — popup open/close from outside.", T_RUN)
        post_command(app, "imgui_open", JV((target = T_POPUP)))
        sleep(1700u)
        post_command(app, "imgui_close", JV((target = T_POPUP)))
        sleep(1500u)
    }
}
