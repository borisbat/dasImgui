options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``drawlist.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_drawlist.das

[export]
def main {
    with_recording_app("examples/tutorial/drawlist.das",
                       "drawlist.apng", 40) $(app) {
        let T_WIN   = "DRAW_WIN"
        let T_INTRO = "DRAW_WIN/DRAW_INTRO"
        let T_BAND  = "DRAW_WIN/DRAW_BAND_SLOT"
        let T_FG    = "DRAW_WIN/DRAW_FG_LABEL"

        var snap = wait_for_render(app, T_INTRO, 10.0f)
        if (snap == null) {
            panic("{T_INTRO} never rendered — wrong app running?")
        }

        say(app, "Three scope wrappers + shape primitives (8 originals + v2 extras) — the drawlist rail.", T_WIN)
        say(app, "with_window_drawlist — rect / line / circle / triangle / text inside the window.", T_BAND)
        say(app, "Shape extras — gradient rect, ellipse, hexagon (ngon), polyline, bezier curves.", T_BAND)
        say(app, "with_foreground_drawlist — paints over every window (top-left FG ribbon).", T_FG)
        say(app, "with_background_drawlist — full-viewport tint behind everything.", T_WIN)
    }
}
