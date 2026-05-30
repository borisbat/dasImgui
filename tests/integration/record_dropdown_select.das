options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``dropdown_select.apng`` against
//! ``examples/tutorial/dropdown_select.das``. Tours four pick-from-list
//! forms — combo (items array), combo_getter (lambda), selectable
//! (multi-toggle rows), selectable_label inside list_box (single-select
//! with caller-owned index).

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
    with_recording_app("examples/tutorial/dropdown_select.das",
                       "dropdown_select.apng", 50) $(app) {
        let T_FRUIT = "DS_WIN/D_FRUIT"
        let T_FONT  = "DS_WIN/D_FONT"
        let T_TAG0  = "DS_WIN/D_TAG[0]"
        let T_TAG1  = "DS_WIN/D_TAG[1]"
        let T_TAG2  = "DS_WIN/D_TAG[2]"
        let T_SHIRT = "DS_WIN/D_SHIRT"

        var snap = wait_for_widget(app, T_FRUIT, 10.0f)
        if (snap == null) {
            panic("{T_FRUIT} never registered — wrong app running?")
        }
        let p_fruit = widget_center(snap, T_FRUIT)
        let p_font  = widget_center(snap, T_FONT)
        let p_tag0  = widget_center(snap, T_TAG0)
        let p_shirt = widget_center(snap, T_SHIRT)

        //! Initial cursor placement.
        move_to(app, p_fruit, 500)
        sleep(SETTLE_MS)

        // ---- Stage 1: combo (items array) — single-call dropdown ----
        post_command(app, "imgui_force_set", JV((target = T_FRUIT, value = 2)))
        sleep(CLICK_DWELL_MS)
        say(app, "combo — items <- ['Apple', ...] in one call. ImGui owns the popup; state.value is the chosen index.", T_FRUIT)
        post_command(app, "imgui_force_set", JV((target = T_FRUIT, value = 4)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 2: combo_getter — procedural list via lambda ----
        move_to(app, p_font, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_force_set", JV((target = T_FONT, value = 1)))
        sleep(CLICK_DWELL_MS)
        say(app, "combo_getter — callback (idx, var result : string&) : bool supplies row text on demand. Use for table/generator-backed lists.", T_FONT)
        post_command(app, "imgui_force_set", JV((target = T_FONT, value = 3)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 3: selectable — N rows, each self-toggles ----
        move_to(app, p_tag0, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_force_set", JV((target = T_TAG0, value = true)))
        sleep(CLICK_DWELL_MS)
        post_command(app, "imgui_force_set", JV((target = T_TAG2, value = true)))
        sleep(CLICK_DWELL_MS)
        say(app, "selectable — each row owns its ToggleState; rows toggle independently. Multi-select naturally.", T_TAG0)
        post_command(app, "imgui_force_set", JV((target = T_TAG1, value = true)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 4: selectable_label in list_box — single-select ----
        move_to(app, p_shirt, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_force_set", JV((target = T_SHIRT, value = 3)))
        sleep(CLICK_DWELL_MS)
        say(app, "selectable_label — caller-owned 'selected' arg. Pair with list_box + an external int to enforce single-select. imgui_force_set on the list_box steers next-frame selection.", T_SHIRT)
        post_command(app, "imgui_force_set", JV((target = T_SHIRT, value = 5)))
        sleep(CLICK_DWELL_MS)
    }
}
