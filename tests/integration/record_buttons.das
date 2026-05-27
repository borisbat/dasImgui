options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``buttons.apng`` against
//! ``examples/tutorial/buttons.das``. Tours six click triggers —
//! button, small_button, arrow_button (pair), invisible_button,
//! image_button (font atlas), tab_item_button inside a tab_bar.

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
    with_recording_app("examples/tutorial/buttons.das",
                       "buttons.apng", 60) $(app) {
        let T_GO    = "BT_WIN/BT_GO"
        let T_SMALL = "BT_WIN/BT_SMALL"
        let T_BACK  = "BT_WIN/BT_BACK"
        let T_FWD   = "BT_WIN/BT_FWD"
        let T_HOT   = "BT_WIN/BT_HOT"
        let T_IMG   = "BT_WIN/BT_IMG"
        let T_HELP  = "BT_WIN/BT_BAR/BT_HELP"
        let T_ADD   = "BT_WIN/BT_BAR/BT_ADD"

        var snap = wait_for_widget(app, T_GO, 10.0f)
        if (snap == null) {
            panic("{T_GO} never registered — wrong app running?")
        }
        let p_go    = widget_center(snap, T_GO)
        let p_small = widget_center(snap, T_SMALL)
        let p_back  = widget_center(snap, T_BACK)
        let p_fwd   = widget_center(snap, T_FWD)
        let p_hot   = widget_center(snap, T_HOT)
        let p_img   = widget_center(snap, T_IMG)
        let p_help  = widget_center(snap, T_HELP)
        let p_add   = widget_center(snap, T_ADD)

        //! Initial cursor placement.
        move_to(app, p_go, 500)
        sleep(SETTLE_MS)

        // ---- Stage 1: button — the workhorse ----
        post_command(app, "imgui_click", JV((target = T_GO)))
        sleep(CLICK_DWELL_MS)
        post_command(app, "imgui_click", JV((target = T_GO)))
        sleep(CLICK_DWELL_MS)
        say(app, "button — ClickState records clicks. Return value is per-frame; state.click_count accumulates.", T_GO)

        // ---- Stage 2: small_button — no padding ----
        move_to(app, p_small, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_click", JV((target = T_SMALL)))
        sleep(CLICK_DWELL_MS)
        say(app, "small_button — SmallButton() has zero frame padding. For inline tool strips (quit, reset, dismiss).", T_SMALL)

        // ---- Stage 3: arrow_button — directional pair ----
        move_to(app, p_back, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_click", JV((target = T_BACK)))
        sleep(CLICK_DWELL_MS)
        post_command(app, "imgui_click", JV((target = T_FWD)))
        sleep(CLICK_DWELL_MS)
        say(app, "arrow_button — triangle glyph; pass dir = ImGuiDir.Up / .Down / .Left / .Right. Each call site needs its own IDENT.", T_BACK)

        // ---- Stage 4: invisible_button — hit area without glyph ----
        move_to(app, p_hot, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_click", JV((target = T_HOT)))
        sleep(CLICK_DWELL_MS)
        say(app, "invisible_button — InvisibleButton(label, size). Clickable bbox, zero render. Overlay one on top of a drawlist scene to capture clicks.", T_HOT)

        // ---- Stage 5: image_button — font atlas as texture ----
        move_to(app, p_img, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_click", JV((target = T_IMG)))
        sleep(CLICK_DWELL_MS)
        say(app, "image_button — pass user_texture_id : void? + size. The font atlas (io.Fonts.TexID) is always available; real apps load their own.", T_IMG)

        // ---- Stage 6: tab_item_button — inside tab_bar ----
        move_to(app, p_help, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_click", JV((target = T_HELP)))
        sleep(CLICK_DWELL_MS)
        post_command(app, "imgui_click", JV((target = T_ADD)))
        sleep(CLICK_DWELL_MS)
        say(app, "tab_item_button — button styled as a tab; MUST be inside a tab_bar. flags = Leading anchors to the start, Trailing to the end. Classic uses: help '?' / add '+'.", T_HELP)
    }
}
