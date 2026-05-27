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
        // tab_item DOES capture a header bbox (current_item_bbox after
        // BeginTabItem), so these paths resolve correctly. The bar itself
        // (TB_WIN/MAIN_TABS) is stateless_finalize without bbox — anchor
        // narration at a tab header instead. See PR #67 Copilot round 1.
        let T_GENERAL = "TB_WIN/MAIN_TABS/GENERAL_TAB"
        let T_AUDIO = "TB_WIN/MAIN_TABS/AUDIO_TAB"
        let T_INFO = "TB_WIN/MAIN_TABS/INFO_TAB"
        let T_DRAFT = "TB_WIN/MAIN_TABS/DRAFT_TAB"

        // wait_for_widget gates on existence; wait_for_render passes
        // through for absent paths.
        var snap = wait_for_widget(app, T_GENERAL, 10.0f)
        if (snap == null) {
            panic("{T_GENERAL} never registered — wrong app running?")
        }
        let p_general = widget_center(snap, T_GENERAL)
        let p_audio = widget_center(snap, T_AUDIO)
        let p_info = widget_center(snap, T_INFO)
        let p_draft = widget_center(snap, T_DRAFT)

        //! Initial cursor placement.
        move_to(app, p_general, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: hover the tab strip ----
        move_to(app, p_general, 900)
        sleep(SETTLE_MS)
        say(app, "tab_bar(IDENT, (flags)) hosts tab_item children. Only the active tab's body block runs; ImGui owns active-tab selection internally.", T_GENERAL)

        // ---- Stage 2: click Audio tab via imgui_click ----
        post_command(app, "imgui_click", JV((target = T_AUDIO)))
        sleep(SWITCH_DWELL_MS)
        move_to(app, p_audio, 700)
        sleep(SETTLE_MS)
        say(app, "imgui_click against a tab header switches the active tab. The General body stopped registering its checkboxes — only Audio's widgets are in the snapshot now.", T_AUDIO)

        // ---- Stage 3: switch to Info ----
        post_command(app, "imgui_click", JV((target = T_INFO)))
        sleep(SWITCH_DWELL_MS)
        move_to(app, p_info, 700)
        sleep(SETTLE_MS)
        say(app, "Tab switching is path-routed — every tab_item is registered under MAIN_TABS/. Drivers don't need access to ImGui internals.", T_INFO)

        // ---- Stage 4: switch to Draft, then close it ----
        post_command(app, "imgui_click", JV((target = T_DRAFT)))
        sleep(SWITCH_DWELL_MS)
        move_to(app, p_draft, 700)
        sleep(SETTLE_MS)
        say(app, "Draft is closable — the X-button next to the label flips state.open=false. Next frame the tab is skipped entirely.", T_DRAFT)

        post_command(app, "imgui_close", JV((target = T_DRAFT)))
        sleep(SWITCH_DWELL_MS)
        // DRAFT_TAB is gone from the registry now; anchor narration at
        // GENERAL_TAB (a still-visible tab header) instead.
        say(app, "imgui_close routes through pending_close — Draft disappears from the strip. imgui_open against the same path re-registers it.", T_GENERAL)

        post_command(app, "imgui_open", JV((target = T_DRAFT)))
        sleep(1500u)
    }
}
