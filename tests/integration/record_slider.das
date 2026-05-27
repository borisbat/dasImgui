options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``slider.apng`` against
//! ``examples/tutorial/slider.das``. Tours four slider forms — scalar
//! float, scalar int, vector float3, and vertical orientation — and
//! drives one value via ``imgui_set`` to show the bidirectional channel.

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
    with_recording_app("examples/tutorial/slider.das",
                       "slider.apng", 60) $(app) {
        let T_FLOAT = "SLIDER_WIN/S_FLOAT"
        let T_INT   = "SLIDER_WIN/S_INT"
        let T_VEC3  = "SLIDER_WIN/S_VEC3"
        let T_VMID  = "SLIDER_WIN/V_MID"

        var snap = wait_for_widget(app, T_FLOAT, 10.0f)
        if (snap == null) {
            panic("{T_FLOAT} never registered — wrong app running?")
        }
        let p_float = widget_center(snap, T_FLOAT)
        let p_int   = widget_center(snap, T_INT)
        let p_vec3  = widget_center(snap, T_VEC3)
        let p_vmid  = widget_center(snap, T_VMID)

        //! Initial cursor placement.
        move_to(app, p_float, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: narrate scalar float ----
        say(app, "slider_float(IDENT, (text, format)) — fixed-width track between (lo, hi). Click track to jump; drag handle to scrub. Bounds REQUIRED.", T_FLOAT)

        // ---- Stage 2: scalar int ----
        move_to(app, p_int, 900)
        sleep(SETTLE_MS)
        say(app, "slider_int — same shape, integer steps. format = \"%d%%\" prints a percent suffix on the label.", T_INT)
        post_command(app, "imgui_set", JV((target = T_INT, value = 7)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 3: vector float3 ----
        move_to(app, p_vec3, 900)
        sleep(SETTLE_MS)
        say(app, "slider_float3 — three handles on one row. State carries float3 value; bounds apply to every component.", T_VEC3)

        // ---- Stage 4: vertical orientation ----
        move_to(app, p_vmid, 900)
        sleep(SETTLE_MS)
        say(app, "vslider_float — same SliderStateFloat, vertical track. size = (width, height) specifies pixel geometry; everything else is identical.", T_VMID)
        post_command(app, "imgui_set", JV((target = T_VMID, value = 0.75f)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 5: drive from outside via imgui_set ----
        post_command(app, "imgui_set", JV((target = T_FLOAT, value = 0.8f)))
        sleep(SET_DWELL_MS)
        post_command(app, "imgui_set", JV((target = T_VEC3, value = (0.6f, -0.3f, 0.9f))))
        sleep(SET_DWELL_MS)
        move_to(app, p_float, 900)
        sleep(SETTLE_MS)
        say(app, "imgui_set writes state.pending_value; next frame consumes it. Same channel for scalar (number) or vector (per-component array).", T_FLOAT)
    }
}
