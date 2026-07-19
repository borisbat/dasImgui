options gen2
options gc
options persistent_heap

require imgui/imgui_harness
require imgui/imgui_terminal
require strings

var private g_terminal : Terminal
var private g_terminal_view = ImGuiTerminalState()

def terminal_command() : string {
    let prefix = "--terminal-command="
    for (arg in get_command_line_arguments()) {
        if (starts_with(arg, prefix)) return slice(arg, length(prefix))
    }
    return "powershell.exe -NoLogo -NoProfile"
}

[export]
def init() {
    harness_init("embedded_terminal", 960, 640)
    var inscope launched <- terminal_launch(terminal_command(), "", 100, 30)
    g_terminal := launched
}

[export]
def update() {
    if (!harness_begin_frame()) return
    // Keep live control responsive even when the child produces output faster
    // than one frame can render. Remaining bytes stay in the PTY pipe.
    for (_ in range(64)) {
        if (terminal_poll(g_terminal) != TerminalPollStatus.data) break
    }
    harness_new_frame()
    SetNextWindowPos(float2(20.0f, 20.0f), ImGuiCond.Always)
    SetNextWindowSize(float2(920.0f, 600.0f), ImGuiCond.Always)
    window(TERMINAL_WIN, (text = "dasHerd terminal", closable = false,
            flags = ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoMove)) {
        let result = imgui_terminal("shell", g_terminal, g_terminal_view)
        text_show(TERMINAL_FOCUS, "{g_terminal_view.focused}")
        text_show(TERMINAL_GEOMETRY,
            "{g_terminal_view.columns}x{g_terminal_view.rows}:{g_terminal_view.resize_revision}")
        text_show(TERMINAL_REVISIONS,
            "{g_terminal_view.input_revision}:{g_terminal_view.content_revision}")
        text_show(TERMINAL_SCREEN, g_terminal_view.screen_text)
    }
    harness_end_frame()
}

[export]
def shutdown() {
    if (!terminal_process_exited(g_terminal)) {
        terminal_terminate(g_terminal)
    }
    terminal_dispose(g_terminal)
    harness_shutdown()
}

[export]
def main() {
    init()
    while (!exit_requested()) {
        update()
        harness_maybe_collect_gc()
    }
    shutdown()
}
