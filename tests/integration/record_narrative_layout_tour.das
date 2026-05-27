options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``narrative_layout_tour.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_boost_narrative_layout.das
//!
//! Walks four boost-v2 families in one window:
//!   1. Narrative widgets (text / text_wrapped / text_colored / text_disabled
//!      / bullet_text / label_text)
//!   2. Layout primitives (separator_text / dummy via spacing fan-out)
//!   3. Display widgets (progress_bar)
//!   4. Flat-form tooltips (set_item_tooltip)

let TAIL_MS = 1500u   //! cushion after final narrate so record_stop doesn't cut the last frame

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
    with_recording_app("examples/tutorial/narrative_layout_tour.das",
                       "narrative_layout_tour.apng", 75) $(app) {
        var snap = wait_for_render(app, "TOUR_WIN/INTRO", 10.0f)
        if (snap == null) {
            panic("TOUR_WIN/INTRO never rendered -- wrong app?")
        }

        let p_intro    = widget_center(snap, "TOUR_WIN/INTRO")
        let p_wrap     = widget_center(snap, "TOUR_WIN/WRAP")
        let p_colored  = widget_center(snap, "TOUR_WIN/COLORED")
        let p_bullet   = widget_center(snap, "TOUR_WIN/BULLET_LINE")
        let p_label    = widget_center(snap, "TOUR_WIN/LABEL_VERSION")
        let p_septitle = widget_center(snap, "TOUR_WIN/SEP_TITLE")
        let p_progress = widget_center(snap, "TOUR_WIN/PROG_BAR")
        let p_tooltip  = widget_center(snap, "TOUR_WIN/HOVER_TIP")

        //! Initial cursor placement (synth IO flips `cursor_owned` on first move).
        move_to(app, (450.0f, 360.0f), 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: plain text ----
        move_to(app, p_intro, 900)
        sleep(SETTLE_MS)
        say(app, "text() -- one line, telemetry-visible.", "TOUR_WIN/INTRO")

        // ---- Stage 2: wrapped text ----
        move_to(app, p_wrap, 900)
        sleep(SETTLE_MS)
        say(app, "text_wrapped reflows to the window's right edge.", "TOUR_WIN/WRAP")

        // ---- Stage 3: colored / disabled / bullet ----
        move_to(app, p_colored, 900)
        sleep(SETTLE_MS)
        say(app, "text_colored + text_disabled -- inline visual variants.", "TOUR_WIN/COLORED")
        move_to(app, p_bullet, 700)
        sleep(SETTLE_MS)
        say(app, "bullet_text -- marker + text in one call.", "TOUR_WIN/BULLET_LINE")

        // ---- Stage 4: label_text (two-string) ----
        move_to(app, p_label, 900)
        sleep(SETTLE_MS)
        say(app, "label_text -- label and value side-by-side.", "TOUR_WIN/LABEL_VERSION")

        // ---- Stage 5: separator_text ----
        move_to(app, p_septitle, 900)
        sleep(SETTLE_MS)
        say(app, "separator_text -- inline section header.", "TOUR_WIN/SEP_TITLE")

        // ---- Stage 6: progress_bar (driven by the host) ----
        move_to(app, p_progress, 900)
        sleep(SETTLE_MS)
        say(app, "progress_bar -- fraction driven from the host loop.", "TOUR_WIN/PROG_BAR")

        // ---- Stage 7: flat tooltip on hover ----
        move_to(app, p_tooltip, 900)
        sleep(SETTLE_MS)
        say(app, "set_item_tooltip -- fires when hovering the previous item.", "TOUR_WIN/HOVER_TIP")
        sleep(TAIL_MS)
    }
}
