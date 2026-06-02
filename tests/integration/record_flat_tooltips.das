options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver: record flat_tooltips.apng against examples/tutorial/flat_tooltips.das.
//! Flat-form tooltips are pure hover surfaces (set_item_tooltip fires only while the previous item is
//! hovered), so we drive them the human way - rest the cursor on each annotated item, never click - and
//! self-verify that the tooltip actually showed. set_item_tooltip now reports rendered=true to the
//! snapshot only on the frames it displays, so record_check_rendered on the tooltip is the honest
//! "the tooltip fired on hover" assertion (a hover that produced no tooltip aborts at teardown).

[export]
def main {
    with_recording_app("examples/tutorial/flat_tooltips.das",
                       "flat_tooltips.apng", 40) $(app) {
        let T_SAVE     = "TOOLTIP_WIN/SAVE_BTN"
        let T_LOAD     = "TOOLTIP_WIN/LOAD_BTN"
        let T_HELP     = "TOOLTIP_WIN/HELP_GLYPH"
        let T_SAVE_TIP = "TOOLTIP_WIN/SAVE_TIP"
        let T_LOAD_TIP = "TOOLTIP_WIN/LOAD_TIP"
        let T_HELP_TIP = "TOOLTIP_WIN/HELP_TIP"

        var snap = wait_for_render(app, T_SAVE, 10.0f)
        if (snap == null) {
            panic("{T_SAVE} never rendered - wrong app running?")
        }

        // ---- Stage 1: hover Save - its tooltip fires ----
        move_to(app, widget_click_point(snap, T_SAVE), 700)
        sleep(SETTLE_MS)
        let d1 = say_begin(app, "set_item_tooltip - fires on item hover", T_SAVE,
            [voice = "A flat tooltip is one line of code right after a widget. Rest the pointer on the Save button and its tooltip appears - no extra layout, no separate scope."])
        record_check_rendered(app, T_SAVE_TIP, true, 180)
        sleep(d1)

        // ---- Stage 2: hover Load - the tooltip follows the hovered item ----
        move_to(app, widget_click_point(snap, T_LOAD), 800)
        sleep(SETTLE_MS)
        let d2 = say_begin(app, "each call attaches to the item above it", T_LOAD,
            [voice = "Each call attaches to the item just before it. Move onto Load and a different tooltip shows - one line per row, written right where you need it."])
        record_check_rendered(app, T_LOAD_TIP, true, 180)
        sleep(d2)

        // ---- Stage 3: the (?) help-marker idiom ----
        move_to(app, widget_click_point(snap, T_HELP), 800)
        sleep(SETTLE_MS)
        let d3 = say_begin(app, "the (?) help-marker idiom", T_HELP,
            [voice = "Put one after a greyed-out question mark and you have a help marker - the same little hint icon you see all over good tools, in just two lines."])
        record_check_rendered(app, T_HELP_TIP, true, 180)
        sleep(d3)
    }
}
