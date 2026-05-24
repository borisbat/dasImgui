options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``group.apng`` against
//! ``examples/tutorial/group.das``. Tours three group patterns —
//! side-by-side via same_line, group-as-hit-target with tooltip, and
//! the (label | value | button) row composition.

let NARRATE_FRAMES = 240        //! 4.0s visible at 60 fps app
let READ_MS    = 5000u          //! 5s read window
let SETTLE_MS  = 1500u          //! 1.5s cursor settle
let HOVER_DWELL_MS = 2200u      //! 2.2s tooltip dwell

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
    with_recording_app("examples/tutorial/group.das",
                       "group.apng", 60) $(app) {
        // Anchor cursor + narration at LEAF widgets inside each group —
        // group's [container] wrapper finalizes without a bbox. See PR #67
        // Copilot round 1.
        let T_LEFT = "GRP_WIN/LEFT_GRP/L_WIRE"
        let T_RIGHT = "GRP_WIN/RIGHT_GRP/R_VSYNC"
        let T_HOVER = "GRP_WIN/HOVER_GRP/HOVER_BTN"
        let T_ROW = "GRP_WIN/ROW_GRP/ROW_RESET"

        var snap = wait_for_render(app, T_LEFT, 10.0f)
        if (snap == null) {
            panic("{T_LEFT} never rendered — wrong app running?")
        }
        let p_left = widget_center(snap, T_LEFT)
        let p_right = widget_center(snap, T_RIGHT)
        let p_hover = widget_center(snap, T_HOVER)
        let p_row = widget_center(snap, T_ROW)

        //! Initial cursor placement.
        move_to(app, p_left, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: side-by-side groups ----
        move_to(app, p_left, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "group(IDENT) wraps BeginGroup/EndGroup. same_line() after a closed group continues from the group's right edge — that's how two stacked column blocks share a row.",
            target = T_LEFT,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        move_to(app, p_right, 700)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "Right group's first text line aligns with the left's — same_line preserved the row baseline. The path push still happens: LEFT_GRP/L_WIRE vs RIGHT_GRP/R_VSYNC.",
            target = T_RIGHT,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: hover the group to fire the combined-bbox tooltip ----
        move_to(app, p_hover, 900)
        sleep(HOVER_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "IsItemHovered() after EndGroup() reports against the combined bbox — hover anywhere in the [i] Info ... Action row to fire the tooltip.",
            target = T_HOVER,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 3: the row pattern ----
        move_to(app, p_row, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "(label | value | button) — common pattern. The group keeps Speed/slider/Reset on one logical row even if the body grows.",
            target = T_ROW,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
    }
}
