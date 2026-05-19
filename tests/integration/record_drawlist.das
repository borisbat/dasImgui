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
                       "drawlist.apng", 30) $(app) {
        let T_WIN   = "DRAW_WIN"
        let T_INTRO = "DRAW_WIN/DRAW_INTRO"
        let T_BAND  = "DRAW_WIN/DRAW_BAND_SLOT"
        let T_FG    = "DRAW_WIN/DRAW_FG_LABEL"

        var snap = wait_for_render(app, T_INTRO, 10.0f)
        if (snap == null) {
            panic("{T_INTRO} never rendered — wrong app running?")
        }

        post_command(app, "imgui_narrate", JV((
            text = "Three scope wrappers + shape primitives (8 originals + v2 extras) — the drawlist rail.",
            target = T_WIN,
            frames = 180
        )))
        sleep(3500u)

        post_command(app, "imgui_narrate", JV((
            text = "with_window_drawlist — rect / line / circle / triangle / text inside the window.",
            target = T_BAND,
            frames = 200
        )))
        sleep(3500u)

        post_command(app, "imgui_narrate", JV((
            text = "Shape extras — gradient rect, ellipse, hexagon (ngon), polyline, bezier curves.",
            target = T_BAND,
            frames = 200
        )))
        sleep(3500u)

        post_command(app, "imgui_narrate", JV((
            text = "with_foreground_drawlist — paints over every window (top-left FG ribbon).",
            target = T_FG,
            frames = 200
        )))
        sleep(3500u)

        post_command(app, "imgui_narrate", JV((
            text = "with_background_drawlist — full-viewport tint behind everything.",
            target = T_WIN,
            frames = 180
        )))
        sleep(1500u)
    }
}
