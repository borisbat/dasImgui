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

let NARRATE_FRAMES = 240        //! 4.0s visible at 60 fps app
let READ_MS    = 5000u          //! 5s read window
let SETTLE_MS  = 1500u          //! 1.5s cursor settle
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
                       "collapsing_header.apng", 60) $(app) {
        // Anchor cursor + narration at LEAF widgets inside each section —
        // collapsing_header finalizes without a bbox. See PR #67 Copilot
        // round 1.
        let T_BASIC_LEAF = "CH_WIN/BASIC_CH/BASIC_LIVE"
        let T_CLOSABLE_LEAF = "CH_WIN/CLOSABLE_CH/VOLUME"
        let T_CLOSABLE_PATH = "CH_WIN/CLOSABLE_CH"
        let T_STARTUP_LEAF = "CH_WIN/STARTUP_CH/STARTUP_HINT"

        var snap = wait_for_render(app, T_BASIC_LEAF, 10.0f)
        if (snap == null) {
            panic("{T_BASIC_LEAF} never rendered — wrong app running?")
        }
        let p_basic = widget_center(snap, T_BASIC_LEAF)
        let p_closable = widget_center(snap, T_CLOSABLE_LEAF)

        //! Initial cursor placement.
        move_to(app, p_basic, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: narrate the basic section ----
        move_to(app, p_basic, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "collapsing_header(IDENT, (text, closable, flags)) — section header that folds via the chevron. Unlike tree_node there's no TreePop pair.",
            target = T_BASIC_LEAF,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: hover the closable section's slider ----
        move_to(app, p_closable, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "closable=true adds an X-button on the right of the header strip. Click X to set state.open=false; the whole row disappears.",
            target = T_CLOSABLE_LEAF,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 3: drive imgui_close on closable header ----
        post_command(app, "imgui_close", JV((target = T_CLOSABLE_PATH)))
        sleep(TOGGLE_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "imgui_close flips pending_close; next frame the closable header is hidden entirely. Re-open via imgui_open against the same target.",
            target = T_BASIC_LEAF,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
        post_command(app, "imgui_open", JV((target = T_CLOSABLE_PATH)))
        sleep(1500u)

        // ---- Stage 4: DefaultOpen flag — narrate via STARTUP_CH path ----
        // Re-snapshot so we see the now-reopened CLOSABLE section's leaf
        // and grab STARTUP_CH for a final narration anchor.
        post_command(app, "imgui_narrate", JV((
            text = "ImGuiTreeNodeFlags.DefaultOpen — first-render expansion; user input afterwards. Same flag enum as tree_node.",
            target = T_STARTUP_LEAF,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
    }
}
