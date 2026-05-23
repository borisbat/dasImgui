options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``narrative_widgets.apng`` against
//! ``examples/tutorial/narrative_widgets.das``. Tour of the read-only display
//! widgets: ``text``, ``text_wrapped``, ``text_colored``, ``text_disabled``,
//! ``bullet`` (+ ``bullet_text``), ``label_text``, ``separator_text``.
//! Only ``BULLET_MARK`` carries an ident; the rest are anonymous —
//! cursor anchors on NARRATIVE_WIN regions by visual offset.

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
    with_recording_app("examples/tutorial/narrative_widgets.das",
                       "narrative_widgets.apng", 60) $(app) {
        let T_BULLET = "NARRATIVE_WIN/BULLET_MARK"

        var snap = wait_for_render(app, T_BULLET, 10.0f)
        if (snap == null) {
            panic("{T_BULLET} never rendered — wrong app running?")
        }
        let p_bullet = widget_center(snap, T_BULLET)

        //! Initial cursor placement — flips synth_cursor_owned.
        move_to(app, (60.0f, 40.0f), 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: top of window — text + text_wrapped ----
        let p_top = (p_bullet._0, p_bullet._1 - 240.0f)
        move_to(app, p_top, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "text() emits a single line and registers a NarrativeState with the call-site string. text_wrapped() reflows to the window's content edge — the payload still carries the full source string regardless of visual wrapping.",
            target = T_BULLET,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: color + emphasis (text_colored, text_disabled) ----
        let p_color = (p_bullet._0, p_bullet._1 - 120.0f)
        move_to(app, p_color, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "text_colored takes an inline float4 + string; text_disabled greys for non-actionable hints. Same NarrativeState payload — visual variants, identical telemetry shape.",
            target = T_BULLET,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 3: bullet glyph at BULLET_MARK ----
        move_to(app, p_bullet, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "bullet(IDENT) emits the marker glyph alone — BULLET_MARK is the only narrative widget with an ident in this tutorial. bullet_text(...) below bundles glyph + text in one call.",
            target = T_BULLET,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 4: label_text below bullet block ----
        let p_label = (p_bullet._0, p_bullet._1 + 140.0f)
        move_to(app, p_label, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "label_text takes (key=, value=). Both strings echo into the payload — perfect for snapshot-driven property-sheet style output.",
            target = T_BULLET,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
    }
}
