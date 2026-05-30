options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``color.apng`` against
//! ``examples/tutorial/color.das``. Tours four color editors + one
//! click trigger — color_edit3, color_edit4, color_picker4 (with
//! ref swatch), color_button (caller-owned swatch).

let SET_DWELL_MS   = 1500u      //! 1.5s post-imgui_force_set dwell

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
    with_recording_app("examples/tutorial/color.das",
                       "color.apng", 45) $(app) {
        let T_EDIT3  = "CO_WIN/CO_EDIT3"
        let T_EDIT4  = "CO_WIN/CO_EDIT4"
        let T_PICKER = "CO_WIN/CO_PICKER"
        let T_SWATCH = "CO_WIN/CO_SWATCH"

        var snap = wait_for_widget(app, T_EDIT3, 10.0f)
        if (snap == null) {
            panic("{T_EDIT3} never registered — wrong app running?")
        }
        let p_edit3  = widget_center(snap, T_EDIT3)
        let p_edit4  = widget_center(snap, T_EDIT4)
        let p_picker = widget_center(snap, T_PICKER)
        let p_swatch = widget_center(snap, T_SWATCH)

        //! Initial cursor placement.
        move_to(app, p_edit3, 500)
        sleep(SETTLE_MS)

        // ---- Stage 1: color_edit3 — inline RGB ----
        post_command(app, "imgui_force_set", JV((target = T_EDIT3, value = (1.0f, 0.5f, 0.0f))))
        sleep(SET_DWELL_MS)
        say(app, "color_edit3 — inline RGB. Click the swatch on the right for ImGui's built-in popup picker. ColorState3 holds value : float3.", T_EDIT3)

        // ---- Stage 2: color_edit4 — same shape + alpha row ----
        move_to(app, p_edit4, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_force_set", JV((target = T_EDIT4, value = (0.2f, 0.4f, 0.9f, 0.6f))))
        sleep(SET_DWELL_MS)
        say(app, "color_edit4 — same widget, RGBA. ColorState4 holds float4; the .a field is the alpha row.", T_EDIT4)

        // ---- Stage 3: color_picker4 — full popout + ref swatch ----
        move_to(app, p_picker, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_force_set", JV((target = T_PICKER, value = (0.9f, 0.3f, 0.7f, 1.0f))))
        sleep(SET_DWELL_MS)
        say(app, "color_picker4 — wheel + sliders inline. has_ref_col=true surfaces the [ref] swatch on the right; pass ref_col to compare against a baseline.", T_PICKER)

        // ---- Stage 4: color_button — caller-owned swatch ----
        move_to(app, p_swatch, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_click", JV((target = T_SWATCH)))
        sleep(SET_DWELL_MS)
        post_command(app, "imgui_click", JV((target = T_SWATCH)))
        sleep(SET_DWELL_MS)
        say(app, "color_button — caller owns the color; the widget records clicks only. Use to surface palette rows or open a custom picker popup. See also color_button_hover.", T_SWATCH)
    }
}
