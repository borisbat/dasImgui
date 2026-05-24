options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``tab_bar.apng`` against
//! ``examples/tutorial/tab_bar.das``. Tours active-tab switching via
//! imgui_click against tab headers and the closable-X behavior.

let NARRATE_FRAMES = 240        //! 4.0s visible at 60 fps app
let READ_MS    = 5000u          //! 5s read window
let SETTLE_MS  = 1500u          //! 1.5s cursor settle
let SWITCH_DWELL_MS = 1800u     //! 1.8s post-tab-switch dwell

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
    with_recording_app("examples/tutorial/tab_bar.das",
                       "tab_bar.apng", 60) $(app) {
        let T_GENERAL = "TB_WIN/MAIN_TABS/GENERAL_TAB"
        let T_AUDIO = "TB_WIN/MAIN_TABS/AUDIO_TAB"
        let T_INFO = "TB_WIN/MAIN_TABS/INFO_TAB"
        let T_DRAFT = "TB_WIN/MAIN_TABS/DRAFT_TAB"
        let T_BAR = "TB_WIN/MAIN_TABS"
        let T_WIN = "TB_WIN"

        var snap = wait_for_render(app, T_GENERAL, 10.0f)
        if (snap == null) {
            panic("{T_GENERAL} never rendered — wrong app running?")
        }
        let p_general = widget_center(snap, T_GENERAL)
        let p_audio = widget_center(snap, T_AUDIO)
        let p_info = widget_center(snap, T_INFO)
        let p_draft = widget_center(snap, T_DRAFT)
        let p_win = widget_center(snap, T_WIN)

        //! Initial cursor placement.
        move_to(app, p_win, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: hover the tab strip ----
        move_to(app, p_general, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "tab_bar(IDENT, (flags)) hosts tab_item children. Only the active tab's body block runs; ImGui owns active-tab selection internally.",
            target = T_BAR,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: click Audio tab via imgui_click ----
        post_command(app, "imgui_click", JV((target = T_AUDIO)))
        sleep(SWITCH_DWELL_MS)
        move_to(app, p_audio, 700)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "imgui_click against a tab header switches the active tab. The General body stopped registering its checkboxes — only Audio's widgets are in the snapshot now.",
            target = T_AUDIO,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 3: switch to Info ----
        post_command(app, "imgui_click", JV((target = T_INFO)))
        sleep(SWITCH_DWELL_MS)
        move_to(app, p_info, 700)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "Tab switching is path-routed — every tab_item is registered under MAIN_TABS/. Drivers don't need access to ImGui internals.",
            target = T_INFO,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 4: switch to Draft, then close it ----
        post_command(app, "imgui_click", JV((target = T_DRAFT)))
        sleep(SWITCH_DWELL_MS)
        move_to(app, p_draft, 700)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "Draft is closable — the X-button next to the label flips state.open=false. Next frame the tab is skipped entirely.",
            target = T_DRAFT,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        post_command(app, "imgui_close", JV((target = T_DRAFT)))
        sleep(SWITCH_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "imgui_close routes through pending_close — Draft disappears from the strip. imgui_open against the same path re-registers it.",
            target = T_BAR,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        post_command(app, "imgui_open", JV((target = T_DRAFT)))
        sleep(1500u)
    }
}
