options gen2

require imgui/imgui_harness

// =============================================================================
// FEATURE: drawlist — window/foreground/background drawlist rail.
//          Exercises every primitive (line/rect/rect_filled/circle/
//          circle_filled/triangle/triangle_filled/text) under one window so
//          tests can wait_for_widget("DRAW_WIN/...") and snapshot bboxes.
// SHOWS:   3 scope wrappers + 8 primitives; foreground swatch overlays the
//          window content; background swatch paints under.
// STANDALONE: daslang.exe modules/dasImgui/examples/features/drawlist.das
// HEADLESS:   daslang.exe modules/dasImgui/examples/features/drawlist.das -- --headless --headless-frames=60
// =============================================================================

[export]
def init() {
    harness_init("drawlist — rail tour", 520, 420)
}

[export]
def update() {
    if (!harness_begin_frame()) return
    harness_new_frame()

    SetNextWindowSize(ImVec2(480.0, 360.0), ImGuiCond.Always)
    window(DRAW_WIN, (text = "drawlist", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text(DRAW_INTRO, (text = "Drawlist primitives below — bboxes are mouse-cards targetable by path."))
        separator()

        let origin = GetCursorScreenPos()
        let red    = rgba(220u,  60u,  60u, 255u)
        let green  = rgba( 60u, 220u, 100u, 255u)
        let blue   = rgba( 70u, 130u, 240u, 255u)
        let yellow = rgba(240u, 220u,  60u, 255u)
        let gray   = rgba(200u, 200u, 210u, 255u)
        let bg_tint = rgba(20u, 30u, 50u, 120u)

        with_window_drawlist() $(var dl) {
            // Filled rect across the canvas band.
            dl |> add_rect_filled(float2(origin.x +   8.0f, origin.y +  8.0f),
                                  float2(origin.x + 460.0f, origin.y + 60.0f),
                                  rgba(35u, 35u, 50u, 200u), 6.0f)
            // Stroked rect inset.
            dl |> add_rect(float2(origin.x +  16.0f, origin.y + 16.0f),
                           float2(origin.x + 452.0f, origin.y + 52.0f),
                           gray, 4.0f, ImDrawFlags.None, 1.5f)
            // Diagonal line.
            dl |> add_line(float2(origin.x +  16.0f, origin.y + 16.0f),
                           float2(origin.x + 452.0f, origin.y + 52.0f),
                           yellow, 2.0f)
            // Circles.
            dl |> add_circle_filled(float2(origin.x +  60.0f, origin.y + 130.0f), 28.0f, blue, 0)
            dl |> add_circle(       float2(origin.x + 130.0f, origin.y + 130.0f), 28.0f, blue, 0, 2.0f)
            // Triangles.
            dl |> add_triangle_filled(float2(origin.x + 220.0f, origin.y + 102.0f),
                                      float2(origin.x + 192.0f, origin.y + 158.0f),
                                      float2(origin.x + 248.0f, origin.y + 158.0f), green)
            dl |> add_triangle(float2(origin.x + 310.0f, origin.y + 102.0f),
                               float2(origin.x + 282.0f, origin.y + 158.0f),
                               float2(origin.x + 338.0f, origin.y + 158.0f), green, 2.0f)
            // Text label.
            dl |> add_text(float2(origin.x +  16.0f, origin.y + 180.0f), gray,
                           "add_text — window drawlist")
        }

        // Reserve layout space for the band painted above so subsequent
        // ImGui widgets land below.
        dummy(DRAW_BAND_SLOT, (size = float2(460.0f, 220.0f)))

        text(DRAW_FG_LABEL, (text = "foreground swatch (overlays window):"))
        // Foreground drawlist — a small red ribbon at the top of the viewport.
        let vp_pos = GetMainViewport().Pos
        let vp_size = GetMainViewport().Size
        with_foreground_drawlist() $(var fdl) {
            fdl |> add_rect_filled(float2(vp_pos.x + 12.0f, vp_pos.y + 12.0f),
                                   float2(vp_pos.x + 80.0f, vp_pos.y + 22.0f),
                                   red)
        }

        // Background drawlist — full-viewport tint behind everything.
        with_background_drawlist() $(var bdl) {
            bdl |> add_rect_filled(float2(vp_pos.x, vp_pos.y),
                                   float2(vp_pos.x + vp_size.x, vp_pos.y + vp_size.y),
                                   bg_tint)
        }
    }

    harness_end_frame()
}

[export]
def shutdown() {
    harness_shutdown()
}

[export]
def main() {
    init()
    while (!exit_requested()) {
        update()
    }
    shutdown()
}
