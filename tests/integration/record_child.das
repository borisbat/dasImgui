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

let NARRATE_FRAMES = 240        //! 4.0s visible at 60 fps app
let READ_MS    = 5000u          //! 5s read window before next stage
let SETTLE_MS  = 1500u          //! 1.5s cursor settle
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
                       "child.apng", 60) $(app) {
        // Anchor every cursor + narration target at a LEAF widget inside each
        // child — container [container] wrappers (child/group/window/etc.)
        // don't capture a bbox on finalize, so addressing the container path
        // resolves to (0,0). Leaves have a real bbox via the per-widget
        // current_item_bbox snapshot. See PR #67 Copilot review round 1.
        let T_A_ROW = "CHILD_WIN/SCROLL_A/SCROLL_ROW[0]"
        let T_A_MID = "CHILD_WIN/SCROLL_A/SCROLL_ROW[5]"
        let T_B_LEAF = "CHILD_WIN/AUTO_B/B_VSYNC"
        let T_C_LEAF = "CHILD_WIN/SCROLL_C/LONG_LINE"

        var snap = wait_for_render(app, T_A_ROW, 10.0f)
        if (snap == null) {
            panic("{T_A_ROW} never rendered — wrong app running?")
        }
        let p_a = widget_center(snap, T_A_ROW)
        let p_a_mid = widget_center(snap, T_A_MID)
        let p_b = widget_center(snap, T_B_LEAF)
        let p_c = widget_center(snap, T_C_LEAF)

        //! Initial cursor placement — flips synth_cursor_owned.
        move_to(app, p_b, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: bordered, scrolled child ----
        move_to(app, p_a, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "child(IDENT, (size, child_flags, window_flags)) — bordered fixed-size with vertical scroll. ChildState.scroll mirrors the visible position.",
            target = T_A_ROW,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

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
        post_command(app, "imgui_narrate", JV((
            text = "scroll.y updates after the wheel scrolls the bordered region — the boost wrapper captures GetScrollY() each frame.",
            target = T_A_MID,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 3: AutoResizeY + FrameStyle ----
        move_to(app, p_b, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "AutoResizeY + FrameStyle — height tracks the body's content extent; FrameStyle gives an input-group chrome border.",
            target = T_B_LEAF,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 4: horizontal scroll ----
        move_to(app, p_c, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "window_flags.HorizontalScrollbar + a wide single line — drag the bottom scroller. scroll.x mirrors the value.",
            target = T_C_LEAF,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
    }
}
