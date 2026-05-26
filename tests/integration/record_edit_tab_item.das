options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``edit_tab_item.apng`` against
//! ``examples/tutorial/edit_tab_item.das``. Drives the bidir bind:
//! toggle the external checkboxes off, watch the corresponding tabs
//! disappear; toggle back on, watch them reappear. The X close button
//! on each tab writes the same bool — symmetric.

let NARRATE_FRAMES = 180        //! 6s visible at the app's 30 fps target
let READ_MS        = 3500u      //! 3.5s read window per stage
let SETTLE_MS      = 1200u      //! 1.2s cursor settle
let SET_DWELL_MS   = 1500u      //! 1.5s post-imgui_set dwell

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
    with_recording_app("examples/tutorial/edit_tab_item.das",
                       "edit_tab_item.apng", 45, 30) $(app) {
        let T_CHECK_A = "ET_WIN/ET_CHECK_A"
        let T_CHECK_B = "ET_WIN/ET_CHECK_B"
        let T_CHECK_C = "ET_WIN/ET_CHECK_C"
        let T_TAB_A   = "ET_WIN/ET_BAR/ET_TAB_A"
        let T_TAB_B   = "ET_WIN/ET_BAR/ET_TAB_B"

        var snap = wait_for_widget(app, T_TAB_A, 10.0f)
        if (snap == null) {
            panic("{T_TAB_A} never registered — wrong app running?")
        }
        let p_tab_a = widget_center(snap, T_TAB_A)
        let p_check_b = widget_center(snap, T_CHECK_B)

        //! Initial cursor placement.
        move_to(app, p_tab_a, 500)
        sleep(SETTLE_MS)

        // ---- Stage 1: external checkbox hides a tab ----
        post_command(app, "imgui_set", JV((target = T_CHECK_B, value = false)))
        sleep(SET_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "edit_tab_item — caller owns the visibility bool. Setting g_tab_b_open = false (via the external checkbox) hides the beta tab entirely — no chrome, no body.",
            target = T_CHECK_B,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: re-enable, then hide gamma instead ----
        post_command(app, "imgui_set", JV((target = T_CHECK_B, value = true)))
        sleep(SET_DWELL_MS)
        post_command(app, "imgui_set", JV((target = T_CHECK_C, value = false)))
        sleep(SET_DWELL_MS)
        move_to(app, p_check_b, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "Bidir-bound — the X close button on each tab header writes the SAME bool. Use this when a second UI surface needs to drive tab visibility; `tab_item`'s internal state.open isn't exposed for write.",
            target = T_CHECK_C,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 3: restore all tabs ----
        post_command(app, "imgui_set", JV((target = T_CHECK_A, value = true)))
        post_command(app, "imgui_set", JV((target = T_CHECK_B, value = true)))
        post_command(app, "imgui_set", JV((target = T_CHECK_C, value = true)))
        sleep(SET_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "All three tabs restored. Same channel writes from external bool or X button — caller stays the source of truth.",
            target = T_TAB_A,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
    }
}
