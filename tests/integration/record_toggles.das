options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``toggles.apng`` against
//! ``examples/tutorial/toggles.das``. Tours three toggle forms — single
//! checkbox, single radio_button (bool-form, same ToggleState as
//! checkbox, only the glyph differs), and grouped radio_button_int
//! (three sites sharing one RadioIntState).

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
    with_recording_app("examples/tutorial/toggles.das",
                       "toggles.apng", 35) $(app) {
        let T_CHECK      = "TG_WIN/T_CHECK"
        let T_RADIO_BOOL = "TG_WIN/T_RADIO_BOOL"
        let T_MODE       = "TG_WIN/T_MODE"

        var snap = wait_for_widget(app, T_CHECK, 10.0f)
        if (snap == null) {
            panic("{T_CHECK} never registered — wrong app running?")
        }
        let p_check = widget_center(snap, T_CHECK)
        let p_radio = widget_center(snap, T_RADIO_BOOL)
        let p_mode  = widget_center(snap, T_MODE)

        //! Initial cursor placement.
        move_to(app, p_check, 500)
        sleep(SETTLE_MS)

        // ---- Stage 1: checkbox — flip on, then off ----
        post_command(app, "imgui_force_set", JV((target = T_CHECK, value = true)))
        sleep(SET_DWELL_MS)
        say(app, "checkbox — single ToggleState bool. Click flips, imgui_force_set writes pending_value.", T_CHECK)

        // ---- Stage 2: radio_button (bool form) — circle-rendered checkbox ----
        move_to(app, p_radio, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_force_set", JV((target = T_RADIO_BOOL, value = true)))
        sleep(SET_DWELL_MS)
        say(app, "radio_button (bool) — SAME ToggleState as checkbox; only the glyph differs (circle vs square).", T_RADIO_BOOL)

        // ---- Stage 3: radio_button_int — grouped, mutually exclusive ----
        move_to(app, p_mode, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_force_set", JV((target = T_MODE, value = 1)))
        sleep(SET_DWELL_MS)
        post_command(app, "imgui_force_set", JV((target = T_MODE, value = 2)))
        sleep(SET_DWELL_MS)
        say(app, "radio_button_int — three call sites SHARE one RadioIntState. Click writes state.value = v_button — the canonical 'pick one of N'.", T_MODE)
    }
}
