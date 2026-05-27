options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``input_numeric.apng`` against
//! ``examples/tutorial/input_numeric.das``. Tours four numeric-input
//! forms — scalar float, scalar int, vector float3, double — and drives
//! ``imgui_set`` on each so the on-screen values visibly change during
//! the narration window.

let SET_DWELL_MS = 1500u    //! 1.5s post-imgui_set dwell

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
    with_recording_app("examples/tutorial/input_numeric.das",
                       "input_numeric.apng", 50) $(app) {
        let T_FLOAT  = "IN_WIN/I_FLOAT"
        let T_INT    = "IN_WIN/I_INT"
        let T_VEC3   = "IN_WIN/I_VEC3"
        let T_DOUBLE = "IN_WIN/I_DOUBLE"

        var snap = wait_for_widget(app, T_FLOAT, 10.0f)
        if (snap == null) {
            panic("{T_FLOAT} never registered — wrong app running?")
        }
        let p_float  = widget_center(snap, T_FLOAT)
        let p_int    = widget_center(snap, T_INT)
        let p_vec3   = widget_center(snap, T_VEC3)
        let p_double = widget_center(snap, T_DOUBLE)

        //! Initial cursor placement.
        move_to(app, p_float, 500)
        sleep(SETTLE_MS)

        // ---- Stage 1: scalar float — narrate AND drive value ----
        post_command(app, "imgui_set", JV((target = T_FLOAT, value = 2.5f)))
        sleep(SET_DWELL_MS)
        say(app, "input_float — click to focus, type, Enter to commit. step / step_fast surface +/- buttons; ctrl-click = step_fast.", T_FLOAT)

        // ---- Stage 2: scalar int ----
        move_to(app, p_int, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_set", JV((target = T_INT, value = 42)))
        sleep(SET_DWELL_MS)
        say(app, "input_int — defaults step=1, step_fast=100. Buttons visible by default.", T_INT)

        // ---- Stage 3: vector float3 ----
        move_to(app, p_vec3, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_set", JV((target = T_VEC3, value = (1.0f, 2.0f, 3.0f))))
        sleep(SET_DWELL_MS)
        say(app, "input_float3 — three text fields, no step args. Tab cycles components; Enter commits the row.", T_VEC3)

        // ---- Stage 4: double precision ----
        move_to(app, p_double, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_set", JV((target = T_DOUBLE, value = 6.283185lf)))
        sleep(SET_DWELL_MS)
        say(app, "input_double — same shape as input_float, double precision (default format %.6f). For time / coords past 7 digits.", T_DOUBLE)

        // ---- Stage 5: drive all to fresh values to show channel ----
        move_to(app, p_float, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_set", JV((target = T_FLOAT, value = 0.5f)))
        post_command(app, "imgui_set", JV((target = T_INT, value = 7)))
        post_command(app, "imgui_set", JV((target = T_VEC3, value = (4.0f, 5.0f, 6.0f))))
        post_command(app, "imgui_set", JV((target = T_DOUBLE, value = 3.141592lf)))
        sleep(SET_DWELL_MS)
        say(app, "imgui_set writes state.pending_value; next frame consumes it. Same channel for scalar, vector, double.", T_FLOAT)
    }
}
