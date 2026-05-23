options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``with_disabled.apng`` against
//! ``examples/tutorial/with_disabled.das``. Tour of the stateless
//! scope-wrappers: ``with_disabled``, ``with_button_repeat``, ``with_font``.
//! The recording flips ENABLED_MASTER on, shows the CHILD_* widgets transition
//! from greyed → active, then exercises STEP_UP under with_button_repeat to
//! make click_count climb visibly.

let NARRATE_FRAMES = 240        //! 4.0s visible at 60 fps app
let READ_MS    = 5000u          //! 5s read window before next stage
let SETTLE_MS  = 1500u          //! 1.5s cursor settle
let RESULT_MS  = 2000u          //! 2s post-click dwell

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
    with_recording_app("examples/tutorial/with_disabled.das",
                       "with_disabled.apng", 60) $(app) {
        let T_ENABLED = "SCOPES_WIN/ENABLED_MASTER"
        let T_CHILD_SAVE = "SCOPES_WIN/CHILD_SAVE"
        let T_STEP_UP = "SCOPES_WIN/STEP_UP"

        var snap = wait_for_render(app, T_ENABLED, 10.0f)
        if (snap == null) {
            panic("{T_ENABLED} never rendered — wrong app running?")
        }
        let p_enabled = widget_center(snap, T_ENABLED)
        let p_child_save = widget_center(snap, T_CHILD_SAVE)
        let p_step = widget_center(snap, T_STEP_UP)

        //! Initial cursor placement — flips synth_cursor_owned.
        move_to(app, (60.0f, 40.0f), 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: hover greyed CHILD_SAVE — with_disabled in effect ----
        move_to(app, p_child_save, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "ENABLED_MASTER is off — with_disabled(!ENABLED_MASTER.value) wraps CHILD_SAVE/LOAD/VOL in BeginDisabled. They render greyed and clicks are inert.",
            target = T_CHILD_SAVE,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: flip ENABLED_MASTER on ----
        move_to(app, p_enabled, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "Click ENABLED_MASTER — the bool flips, with_disabled's argument becomes false next frame, and child widgets become live.",
            target = T_ENABLED,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
        var enable_events : array<JsonValue?>
        enable_events |> click_at(0, p_enabled, 250)
        post_command(app, "imgui_mouse_play", JV((events = enable_events)))
        sleep(RESULT_MS)

        // ---- Stage 3: re-hover CHILD_SAVE — now active ----
        move_to(app, p_child_save, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "Same widget, no code change — the scope wrapper's argument drives the disabled state. CHILD_SAVE/LOAD/VOL are now interactive.",
            target = T_CHILD_SAVE,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 4: with_button_repeat on STEP_UP — held click_count climb ----
        move_to(app, p_step, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "with_button_repeat(true) wraps STEP_UP — holding the button fires click events at ImGui's repeat rate. click_count climbs visibly in the state readout below.",
            target = T_STEP_UP,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
        var step_events : array<JsonValue?>
        step_events |> click_at(0, p_step, 250)
        step_events |> click_at(1500, p_step, 0)
        step_events |> click_at(3000, p_step, 0)
        step_events |> click_at(4500, p_step, 0)
        post_command(app, "imgui_mouse_play", JV((events = step_events)))
        sleep(RESULT_MS)
    }
}
