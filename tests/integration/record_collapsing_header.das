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
//! basic, closable (X-button), and DefaultOpen.

let NARRATE_FRAMES = 240        //! 4.0s visible at 60 fps app
let READ_MS    = 5000u          //! 5s read window
let SETTLE_MS  = 1500u          //! 1.5s cursor settle
let CHEVRON_DWELL_MS = 2200u    //! 2.2s post-chevron-click dwell

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

def widget_left_edge(var snap : JsonValue?; ident : string) : tuple<float; float> {
    let b = widget_bbox(snap, ident)
    // Chevron sits in the first ~16px of the header row.
    return (b.x + 10.0f, (b.y + b.w) * 0.5f)
}

[export]
def main {
    with_recording_app("examples/tutorial/collapsing_header.das",
                       "collapsing_header.apng", 60) $(app) {
        let T_BASIC = "CH_WIN/BASIC_CH"
        let T_CLOSABLE = "CH_WIN/CLOSABLE_CH"
        let T_STARTUP = "CH_WIN/STARTUP_CH"
        let T_WIN = "CH_WIN"

        var snap = wait_for_render(app, T_BASIC, 10.0f)
        if (snap == null) {
            panic("{T_BASIC} never rendered — wrong app running?")
        }
        let p_basic = widget_center(snap, T_BASIC)
        let p_basic_chevron = widget_left_edge(snap, T_BASIC)
        let p_closable = widget_center(snap, T_CLOSABLE)
        let p_startup = widget_center(snap, T_STARTUP)
        let p_win = widget_center(snap, T_WIN)

        //! Initial cursor placement.
        move_to(app, p_win, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: hover the basic header, narrate ----
        move_to(app, p_basic, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "collapsing_header(IDENT, (text, closable, flags)) — section header that folds via the chevron on the left. Unlike tree_node there's no TreePop pair.",
            target = T_BASIC,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: click the basic chevron to collapse ----
        var collapse_events : array<JsonValue?>
        collapse_events |> click_at(0, p_basic_chevron, 200)
        post_command(app, "imgui_mouse_play", JV((events = collapse_events)))
        sleep(CHEVRON_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "Chevron click toggles opened — the body stops rendering until reopened. State.opened mirrors the per-frame fold.",
            target = T_BASIC,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
        var expand_events : array<JsonValue?>
        expand_events |> click_at(0, p_basic_chevron, 200)
        post_command(app, "imgui_mouse_play", JV((events = expand_events)))
        sleep(1500u)

        // ---- Stage 3: closable header ----
        move_to(app, p_closable, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "closable=true adds an X-button on the right of the header strip. Click X to set state.open=false; the whole row disappears.",
            target = T_CLOSABLE,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 4: drive imgui_close on closable header ----
        post_command(app, "imgui_close", JV((target = T_CLOSABLE)))
        sleep(1800u)
        post_command(app, "imgui_narrate", JV((
            text = "imgui_close flips pending_close; next frame the closable header is hidden entirely. Re-open via imgui_open against the same target.",
            target = T_WIN,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
        post_command(app, "imgui_open", JV((target = T_CLOSABLE)))
        sleep(1500u)

        // ---- Stage 5: DefaultOpen ----
        move_to(app, p_startup, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "ImGuiTreeNodeFlags.DefaultOpen — first-render expansion; user input afterwards. Same flag enum as tree_node.",
            target = T_STARTUP,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
    }
}

