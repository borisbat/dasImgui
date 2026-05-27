options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``child.apng`` against
//! ``examples/tutorial/child.das``. Tours three ``child`` variants —
//! bordered + scrolled, AutoResizeY + FrameStyle, and horizontal-scroll.
//! Each stage drives the visible widgets (checkbox, slider, scroll) so
//! ChildState.scroll telemetry below visibly responds, not just narrates.

let SCROLL_DWELL_MS = 1800u     //! 1.8s post-scroll dwell

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
    with_recording_app("examples/tutorial/child.das",
                       "child.apng", 75) $(app) {
        // Anchor every cursor + narration target at a LEAF widget inside each
        // child — container [container] wrappers (child/group/window/etc.)
        // don't capture a bbox on finalize, so addressing the container path
        // resolves to (0,0). Leaves have a real bbox via the per-widget
        // current_item_bbox snapshot. See PR #67 Copilot review round 1.
        let T_A_ROW = "CHILD_WIN/SCROLL_A/SCROLL_ROW[0]"
        let T_A_MID = "CHILD_WIN/SCROLL_A/SCROLL_ROW[5]"
        let T_B_VSYNC = "CHILD_WIN/AUTO_B/B_VSYNC"
        let T_B_LIMIT = "CHILD_WIN/AUTO_B/B_LIMIT"
        let T_C_LEAF = "CHILD_WIN/SCROLL_C/LONG_LINE"

        // wait_for_widget gates on path EXISTENCE; wait_for_render's
        // widget_rendered defaults to true for absent paths, so a typoed
        // target would slip past and bboxes would silently be (0,0).
        var snap = wait_for_widget(app, T_A_ROW, 10.0f)
        if (snap == null) {
            panic("{T_A_ROW} never registered — wrong app running?")
        }
        let p_a = widget_center(snap, T_A_ROW)
        let p_a_mid = widget_center(snap, T_A_MID)
        let p_b_vsync = widget_center(snap, T_B_VSYNC)
        let p_b_limit = widget_center(snap, T_B_LIMIT)
        let p_c = widget_center(snap, T_C_LEAF)

        //! Initial cursor placement — flips synth_cursor_owned.
        move_to(app, p_b_vsync, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: bordered, scrolled child ----
        move_to(app, p_a, 900)
        sleep(SETTLE_MS)
        say(app, "child(IDENT, (size, child_flags, window_flags)) — bordered fixed-size with vertical scroll. ChildState.scroll mirrors the visible position.", T_A_ROW)

        // ---- Stage 2: wheel-scroll the bordered child via imgui_mouse_scroll ----
        // Park the cursor mid-child so ImGui attributes the wheel event to SCROLL_A.
        move_to(app, p_a_mid, 600)
        sleep(SETTLE_MS)
        post_command(app, "imgui_mouse_scroll", JV((x = 0.0f, y = -3.0f)))
        sleep(400u)
        post_command(app, "imgui_mouse_scroll", JV((x = 0.0f, y = -3.0f)))
        sleep(400u)
        post_command(app, "imgui_mouse_scroll", JV((x = 0.0f, y = -3.0f)))
        sleep(SCROLL_DWELL_MS)
        say(app, "scroll.y updates after the wheel scrolls the bordered region — the boost wrapper captures GetScrollY() each frame.", T_A_MID)

        // ---- Stage 3: AutoResizeY child — flip VSync, drag the frame-limit slider ----
        move_to(app, p_b_vsync, 900)
        sleep(SETTLE_MS)
        click(app, T_B_VSYNC)
        sleep(CLICK_DWELL_MS)
        say(app, "AutoResizeY + FrameStyle — height tracks the body's content extent. VSync checkbox toggles inside the auto-resized chrome.", T_B_VSYNC)

        move_to(app, p_b_limit, 700)
        sleep(SETTLE_MS)
        set_value(app, T_B_LIMIT, JV(120))
        sleep(CLICK_DWELL_MS)
        say(app, "Frame-limit slider set to 120 via imgui_set — the AutoResizeY child grows/shrinks to accommodate body width, not height.", T_B_LIMIT)

        // ---- Stage 4: horizontal scroll on SCROLL_C ----
        move_to(app, p_c, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_mouse_scroll", JV((x = -5.0f, y = 0.0f)))
        sleep(400u)
        post_command(app, "imgui_mouse_scroll", JV((x = -5.0f, y = 0.0f)))
        sleep(SCROLL_DWELL_MS)
        say(app, "window_flags.HorizontalScrollbar + a wide single line — wheel-scrolled horizontally. scroll.x mirrors the value live.", T_C_LEAF)
    }
}
