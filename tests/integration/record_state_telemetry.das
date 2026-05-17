options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``state_telemetry.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_state_telemetry.das

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
    with_recording_app("examples/tutorial/state_telemetry.das",
                       "state_telemetry.apng", 60) $(app) {
        //! Targets are path-qualified — the `window(STATE_WIN, ...)` boost
        //! container pushes its name onto the registry path.
        let T_SAVE     = "STATE_WIN/SAVE_BTN"
        let T_SPEED    = "STATE_WIN/SPEED"
        let T_VOLUME   = "STATE_WIN/VOLUME"
        let T_STATUS   = "STATE_WIN/STATUS_TEXT"
        let T_BUMP     = "STATE_WIN/BUMP_STATUS"

        var snap = wait_for_render(app, T_SAVE, 10.0f)
        if (snap == null) {
            panic("{T_SAVE} never rendered — wrong app running?")
        }
        let p_save   = widget_center(snap, T_SAVE)
        let p_bump   = widget_center(snap, T_BUMP)

        //! Pacing rule (LOCKED): `frames` is the app's frame counter (60 fps
        //! under vsync), NOT the recorder's fps. For ~3s readable narrate:
        //!     frames = 180   →  3.0s visible
        //!     sleep  = 3500u →  narrate disappears with ~500ms gap before next
        //! Then ~1500ms result dwell after the action.

        // ---- Stage 1: auto-emit + click_count ----
        post_command(app, "imgui_narrate", JV((
            text = "button(SAVE_BTN, ...) auto-emits the SAVE_BTN global.",
            target = T_SAVE,
            frames = 200
        )))
        move_to(app, p_save)
        sleep(3500u)
        var save_events : array<JsonValue?>
        save_events |> click_at(0, p_save)
        post_command(app, "imgui_mouse_play", JV((events = save_events)))
        sleep(1500u)
        // second click to make click_count tick visibly
        var save_events2 : array<JsonValue?>
        save_events2 |> click_at(0, p_save)
        post_command(app, "imgui_mouse_play", JV((events = save_events2)))
        sleep(1500u)

        // ---- Stage 2: dotted flags steer the emitted global ----
        post_command(app, "imgui_narrate", JV((
            text = "Dotted flags: SPEED.PUBLIC, VOLUME.NOTLIVE.",
            target = T_SPEED,
            frames = 200
        )))
        sleep(3500u)
        // imgui_set drives the slider values without simulating a drag.
        post_command(app, "imgui_set", JV((target = T_SPEED, value = 7)))
        sleep(900u)
        post_command(app, "imgui_set", JV((target = T_VOLUME, value = 0.65f)))
        sleep(1500u)

        // ---- Stage 3: text_show + imgui_set drives the value from outside ----
        post_command(app, "imgui_narrate", JV((
            text = "text_show — app-side value mirrored into the snapshot.",
            target = T_STATUS,
            frames = 200
        )))
        sleep(3500u)
        post_command(app, "imgui_set", JV((target = T_STATUS, value = "set from outside")))
        sleep(1500u)

        // ---- Stage 4: bump rewrites STATUS from inside the app ----
        post_command(app, "imgui_narrate", JV((
            text = "Bump rewrites STATUS_TEXT.value from inside the app.",
            target = T_BUMP,
            frames = 200
        )))
        move_to(app, p_bump)
        sleep(3500u)
        var bump_events : array<JsonValue?>
        bump_events |> click_at(0, p_bump)
        post_command(app, "imgui_mouse_play", JV((events = bump_events)))
        sleep(2000u)
    }
}
