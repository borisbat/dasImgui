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

        // ---- Stage 1: auto-emit + click_count ----
        move_to(app, p_save)
        say(app, "button(SAVE_BTN, ...) auto-emits the SAVE_BTN global.", T_SAVE)
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
        say(app, "Dotted flags: SPEED.PUBLIC, VOLUME.NOTLIVE.", T_SPEED)
        // imgui_set drives the slider values without simulating a drag.
        post_command(app, "imgui_set", JV((target = T_SPEED, value = 7)))
        sleep(900u)
        post_command(app, "imgui_set", JV((target = T_VOLUME, value = 0.65f)))
        sleep(1500u)

        // ---- Stage 3: text_show + imgui_set drives the value from outside ----
        say(app, "text_show — app-side value mirrored into the snapshot.", T_STATUS)
        post_command(app, "imgui_set", JV((target = T_STATUS, value = "set from outside")))
        sleep(1500u)

        // ---- Stage 4: bump rewrites STATUS from inside the app ----
        move_to(app, p_bump)
        say(app, "Bump rewrites STATUS_TEXT.value from inside the app.", T_BUMP)
        var bump_events : array<JsonValue?>
        bump_events |> click_at(0, p_bump)
        post_command(app, "imgui_mouse_play", JV((events = bump_events)))
        sleep(2000u)
    }
}
