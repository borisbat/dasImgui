options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``collapsing_header.apng`` against
//! ``examples/tutorial/collapsing_header.das``. Tours three variants —
//! basic, closable (X-button), and DefaultOpen. Open/close is driven
//! via imgui_open / imgui_close because collapsing_header's [container]
//! wrapper doesn't capture a header bbox (chevron click would need one).
//! Drives BASIC_LIVE checkbox (Stage 1) and VOLUME slider (Stage 2)
//! inside the opened sections — the audit found these were narrate-only.

let TOGGLE_DWELL_MS = 2200u     //! 2.2s post-toggle dwell

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
    with_recording_app("examples/tutorial/collapsing_header.das",
                       "collapsing_header.apng", 75) $(app) {
        // Anchor cursor + narration at LEAF widgets inside each section —
        // collapsing_header finalizes without a bbox. See PR #67 Copilot
        // round 1.
        let T_BASIC_PATH = "CH_WIN/BASIC_CH"
        let T_BASIC_LEAF = "CH_WIN/BASIC_CH/BASIC_LIVE"
        let T_CLOSABLE_LEAF = "CH_WIN/CLOSABLE_CH/VOLUME"
        let T_CLOSABLE_PATH = "CH_WIN/CLOSABLE_CH"
        let T_STARTUP_LEAF = "CH_WIN/STARTUP_CH/STARTUP_HINT"

        // Startup gate on STARTUP_HINT — STARTUP_CH and CLOSABLE_CH are
        // DefaultOpen so their leaves register frame 1, but BASIC_CH is NOT
        // DefaultOpen and its body stays unrendered until we imgui_open it.
        var snap = wait_for_widget(app, T_STARTUP_LEAF, 10.0f)
        if (snap == null) {
            panic("{T_STARTUP_LEAF} never registered — wrong app running?")
        }
        let p_closable = widget_center(snap, T_CLOSABLE_LEAF)

        // Open BASIC_CH so its body widgets exist for Stage 1 narration.
        post_command(app, "imgui_open", JV((target = T_BASIC_PATH)))
        sleep(TOGGLE_DWELL_MS)
        var snap_basic = wait_for_widget(app, T_BASIC_LEAF, 5.0f)
        if (snap_basic == null) {
            panic("{T_BASIC_LEAF} never registered after imgui_open {T_BASIC_PATH}")
        }
        let p_basic = widget_center(snap_basic, T_BASIC_LEAF)

        //! Initial cursor placement.
        move_to(app, p_basic, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: narrate basic + flip BASIC_LIVE checkbox ----
        move_to(app, p_basic, 900)
        sleep(SETTLE_MS)
        say(app, "collapsing_header(IDENT, (text, closable, flags)) — section header that folds via the chevron. Unlike tree_node there's no TreePop pair.", T_BASIC_LEAF)
        click(app, T_BASIC_LEAF)
        sleep(CLICK_DWELL_MS)
        say(app, "BASIC_LIVE checkbox flipped — body widgets work normally inside the opened section.", T_BASIC_LEAF)

        // ---- Stage 2: drive VOLUME slider inside the closable section ----
        move_to(app, p_closable, 900)
        sleep(SETTLE_MS)
        force_set_value(app, T_CLOSABLE_LEAF, JV(72))
        sleep(CLICK_DWELL_MS)
        say(app, "VOLUME slider set to 72 inside CLOSABLE_CH — closable=true adds an X-button on the right of the header strip that flips state.open=false.", T_CLOSABLE_LEAF)

        // ---- Stage 3: drive imgui_close on closable header ----
        post_command(app, "imgui_close", JV((target = T_CLOSABLE_PATH)))
        sleep(TOGGLE_DWELL_MS)
        say(app, "imgui_close flips pending_close; next frame the chevron collapses and the body stops rendering. The header STRIP stays visible — only the X-button (or app code setting state.open=false) hides the whole row.", T_BASIC_LEAF)
        post_command(app, "imgui_open", JV((target = T_CLOSABLE_PATH)))
        sleep(1500u)

        // ---- Stage 4: DefaultOpen flag — narrate via STARTUP_CH path ----
        say(app, "ImGuiTreeNodeFlags.DefaultOpen — first-render expansion; user input afterwards. Same flag enum as tree_node.", T_STARTUP_LEAF)
    }
}
