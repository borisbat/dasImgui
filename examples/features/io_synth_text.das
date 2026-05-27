options gen2

require imgui/imgui_harness

// =============================================================================
// FEATURE: io_synth_text — Phase 2.2 L1 keyboard input synthesis.
// SHOWS:   imgui_type_text live_command — coroutine pushes one
//          AddInputCharactersUTF8 per frame to whichever widget holds
//          keyboard focus. The example auto-focuses DEMO_INPUT on first
//          render via SetKeyboardFocusHere(0), then chars stream in.
//          Phase 2.4 will add a `target`-driven focus action so callers can
//          aim type_text at any widget without owning the focus dance.
// DRIVE:   curl -X POST -d '{"name":"imgui_type_text","args":{"target":"MAIN_WIN/DEMO_INPUT","text":"hello"}}' \
//              localhost:9090/command
//          curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
//              | jq '.globals."MAIN_WIN/DEMO_INPUT".payload.value'
// STANDALONE: daslang.exe modules/dasImgui/examples/features/io_synth_text.das
// HEADLESS:   daslang.exe modules/dasImgui/examples/features/io_synth_text.das -- --headless --headless-frames=60
// LIVE:       daslang-live modules/dasImgui/examples/features/io_synth_text.das
// =============================================================================

var auto_focused = false

[export]
def init() {
    harness_init("Phase 2.2 — io_synth_text", 800, 600)
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.5
}

[export]
def update() {
    if (!harness_begin_frame()) return
    harness_new_frame()

    SetNextWindowSize(ImVec2(720.0, 220.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "io_synth_text — phase 2.2", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text("L1 keyboard: imgui_type_text streams chars one frame each.")
        text("DEMO_INPUT auto-focused on first render via SetKeyboardFocusHere.")
        if (!auto_focused) {
            SetKeyboardFocusHere(0)
            auto_focused = true
        }
        input_text(DEMO_INPUT, (text = "Type here"))
        text("buffer = {DEMO_INPUT.value}")
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
