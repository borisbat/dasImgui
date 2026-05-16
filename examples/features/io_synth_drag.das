options gen2

require imgui/imgui_harness

// =============================================================================
// FEATURE: io_synth_drag — Phase 2.2 L1 mouse-drag synthesis.
// SHOWS:   imgui_drag live_command — coroutine-driven AddMousePosEvent +
//          AddMouseButtonEvent stream resolves the target via g_registry,
//          presses at bbox center, walks N interpolated steps, releases.
//          During the drag, snapshot.io.active_widget binds to DEMO_SLIDER
//          and the slider value moves; both observable through imgui_snapshot.
// DRIVE:   curl -X POST -d '{"name":"imgui_drag","args":{"target":"MAIN_WIN/DEMO_SLIDER","dx":120.0,"dy":0.0,"steps":8}}' \
//              localhost:9090/command
//          curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
//              | jq '{active: .io.active_widget, value: .globals."MAIN_WIN/DEMO_SLIDER".payload.value}'
// STANDALONE: daslang.exe modules/dasImgui/examples/features/io_synth_drag.das
// HEADLESS:   daslang.exe modules/dasImgui/examples/features/io_synth_drag.das -- --headless --headless-frames=60
// LIVE:       daslang-live modules/dasImgui/examples/features/io_synth_drag.das
// =============================================================================

[export]
def init() {
    harness_init("Phase 2.2 — io_synth_drag", 800, 600)
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.5
    DEMO_SLIDER.bounds = (0.0f, 1000.0f)
}

[export]
def update() {
    if (!harness_begin_frame()) return
    advance_coroutines()
    harness_new_frame()

    SetNextWindowSize(ImVec2(720.0, 220.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "io_synth_drag — phase 2.2", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text("L1 drag: imgui_drag synthesizes mouse press → moves → release.")
        text("During the drag, io.active_widget == 'MAIN_WIN/DEMO_SLIDER'.")
        slider_float(DEMO_SLIDER, (text = "Drag me"))
        text("slider value = {DEMO_SLIDER.value}")
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
