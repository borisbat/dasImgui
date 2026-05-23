options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``flat_tooltips.apng`` against
//! ``examples/tutorial/flat_tooltips.das``. Tour of the v2 flat-form tooltip
//! widgets: ``set_item_tooltip`` after a button fires its tooltip on hover,
//! and the disabled "(?)" + ``set_item_tooltip`` idiom is the dasImgui
//! replacement for the imgui_demo HelpMarker helper.

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
    with_recording_app("examples/tutorial/flat_tooltips.das",
                       "flat_tooltips.apng", 45) $(app) {
        let T_SAVE = "TOOLTIP_WIN/SAVE_BTN"
        let T_LOAD = "TOOLTIP_WIN/LOAD_BTN"

        var snap = wait_for_render(app, T_SAVE, 10.0f)
        if (snap == null) {
            panic("{T_SAVE} never rendered — wrong app running?")
        }
        let p_save = widget_center(snap, T_SAVE)
        let p_load = widget_center(snap, T_LOAD)

        //! Initial cursor placement — flips synth_cursor_owned.
        move_to(app, (60.0f, 40.0f), 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: hover SAVE_BTN — tooltip fires ----
        move_to(app, p_save, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "set_item_tooltip after a button fires its tooltip on hover. No layout scope, no extra widgets — one line per annotation.",
            target = T_SAVE,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: hover LOAD_BTN — tooltip follows the hovered item ----
        move_to(app, p_load, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "Each call attaches to the most-recently-submitted item — chain `button(); set_item_tooltip(...)` per row.",
            target = T_LOAD,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 3: HelpMarker pattern under the "(?)" glyph ----
        //! The "(?)" glyph is a raw text_disabled call with no ident; its
        //! position is below LOAD_BTN by ~40px. Hover by visual offset.
        let p_help = (p_load._0 + 80.0f, p_load._1 + 60.0f)
        move_to(app, p_help, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "Disabled `(?)` glyph + set_item_tooltip — the v2 replacement for the imgui_demo HelpMarker helper. Two source lines instead of a multiline helper.",
            target = T_LOAD,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
    }
}
