options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``layout_primitives.apng`` against
//! ``examples/tutorial/layout_primitives.das``. Tour of the cursor-moving
//! layout markers: ``same_line``, ``spacing``, ``new_line``, ``dummy``.
//! Three buttons BTN_A/B/C share one ``same_line`` row; the rest of the
//! window stacks spacing + new_line + dummy demonstrations.

let NARRATE_FRAMES = 240        //! 4.0s visible at 60 fps app
let READ_MS    = 5000u          //! 5s read window before next stage
let SETTLE_MS  = 1500u          //! 1.5s cursor settle

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
    with_recording_app("examples/tutorial/layout_primitives.das",
                       "layout_primitives.apng", 45) $(app) {
        let T_BTN_A = "LAYOUT_WIN/BTN_A"
        let T_BTN_B = "LAYOUT_WIN/BTN_B"
        let T_BTN_C = "LAYOUT_WIN/BTN_C"

        var snap = wait_for_render(app, T_BTN_A, 10.0f)
        if (snap == null) {
            panic("{T_BTN_A} never rendered — wrong app running?")
        }
        let p_a = widget_center(snap, T_BTN_A)
        let p_b = widget_center(snap, T_BTN_B)
        let p_c = widget_center(snap, T_BTN_C)

        //! Initial cursor placement — flips synth_cursor_owned.
        move_to(app, (60.0f, 40.0f), 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: hover BTN_A — establish the same_line row ----
        move_to(app, p_a, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "same_line() keeps the next widget on the current row. Three buttons + two same_line() calls = one horizontal strip.",
            target = T_BTN_A,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: traverse the row ----
        move_to(app, p_b, 700)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "BTN_B is on the same row as BTN_A — the cursor's X advanced via same_line() between calls.",
            target = T_BTN_B,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        move_to(app, p_c, 700)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "BTN_C closes the row. Without same_line(), each button would stack vertically as ImGui's cursor reset to the next line.",
            target = T_BTN_C,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 3: spacing / new_line / dummy commentary ----
        //! Below BTN_C the tutorial stacks: spacing(), three more spacings,
        //! a new_line(), and a dummy(0,40). All anonymous in the snapshot —
        //! the layout markers are visible in the rendered framebuffer but
        //! don't register as routable widgets.
        let p_below = (p_c._0 - 80.0f, p_c._1 + 90.0f)
        move_to(app, p_below, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "spacing() inserts one line of vertical gap. new_line() advances a full text line. dummy((size)) reserves arbitrary cursor space — all three move the cursor without rendering.",
            target = T_BTN_C,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
    }
}
