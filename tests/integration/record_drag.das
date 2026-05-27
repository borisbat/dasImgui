options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``drag.apng`` against
//! ``examples/tutorial/drag.das``. Tours four drag forms — scalar float,
//! scalar int, vector float3, and float range pair — narrating each in
//! turn and driving one value via ``imgui_set`` to show the bidirectional
//! channel.

let SET_DWELL_MS   = 2200u      //! 2.2s post-imgui_set dwell

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
    with_recording_app("examples/tutorial/drag.das",
                       "drag.apng", 60) $(app) {
        let T_FLOAT = "DRAG_WIN/D_FLOAT"
        let T_INT   = "DRAG_WIN/D_INT"
        let T_VEC3  = "DRAG_WIN/D_VEC3"
        let T_RANGE = "DRAG_WIN/D_RANGE"

        var snap = wait_for_widget(app, T_FLOAT, 10.0f)
        if (snap == null) {
            panic("{T_FLOAT} never registered — wrong app running?")
        }
        let p_float = widget_center(snap, T_FLOAT)
        let p_int   = widget_center(snap, T_INT)
        let p_vec3  = widget_center(snap, T_VEC3)
        let p_range = widget_center(snap, T_RANGE)

        //! Initial cursor placement.
        move_to(app, p_float, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: narrate scalar float ----
        say(app, "drag_float(IDENT, (text, speed, format)) — click and drag horizontally to scrub. Bounds = (0, 1) clamps; speed = 0.005 means 0.005 units per pixel.", T_FLOAT)

        // ---- Stage 2: scalar int ----
        move_to(app, p_int, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_set", JV((target = T_INT, value = 42)))
        sleep(SET_DWELL_MS)
        say(app, "drag_int — same shape, integer steps. format = \"%d\" by default; speed = 1 means one integer per pixel.", T_INT)

        // ---- Stage 3: vector float3 ----
        move_to(app, p_vec3, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_set", JV((target = T_VEC3, value = (0.5f, 1.0f, 1.5f))))
        sleep(SET_DWELL_MS)
        say(app, "drag_float3 — three components on one row. State carries float3 value; bounds clamp every component.", T_VEC3)

        // ---- Stage 4: range pair ----
        move_to(app, p_range, 900)
        sleep(SETTLE_MS)
        say(app, "drag_float_range2 — two handles share one bar. value.x = lo, value.y = hi; ImGui enforces lo <= hi each frame.", T_RANGE)

        // ---- Stage 5: drive from outside via imgui_set ----
        post_command(app, "imgui_set", JV((target = T_FLOAT, value = 0.75f)))
        sleep(SET_DWELL_MS)
        post_command(app, "imgui_set", JV((target = T_RANGE, value = (20.0f, 65.0f))))
        sleep(SET_DWELL_MS)
        move_to(app, p_float, 900)
        sleep(SETTLE_MS)
        say(app, "imgui_set writes through state.pending_value; next frame consumes it. Same channel for scalar (number) or range (two-number tuple).", T_FLOAT)
    }
}
