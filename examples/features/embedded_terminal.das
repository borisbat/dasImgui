options gen2

require imgui/imgui_harness
require imgui/imgui_terminal
require strings

def terminal_command() : string {
    let prefix = "--terminal-command="
    for (arg in get_command_line_arguments()) {
        if (starts_with(arg, prefix)) return slice(arg, length(prefix))
    }
    return "powershell.exe -NoLogo -NoProfile"
}

def update(terminal : Terminal const; var terminal_view : ImGuiTerminalState) {
    if (!harness_begin_frame()) return
    while (terminal_poll(terminal) == TerminalPollStatus.data) {
    }
    harness_new_frame()
    SetNextWindowPos(float2(20.0f, 20.0f), ImGuiCond.Always)
    SetNextWindowSize(float2(920.0f, 600.0f), ImGuiCond.Always)
    window(TERMINAL_WIN, (text = "dasHerd terminal", closable = false,
            flags = ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoMove)) {
        let result = imgui_terminal("shell", terminal, terminal_view)
    }
    harness_end_frame()
}

def shutdown(terminal : Terminal const) {
    if (!terminal_process_exited(terminal)) {
        terminal_terminate(terminal)
    }
    harness_shutdown()
}

[export]
def main() {
    harness_init("embedded_terminal", 960, 640)
    var inscope terminal <- terminal_launch(
        terminal_command(), "", 100, 30)
    var terminal_view = ImGuiTerminalState()
    while (!exit_requested()) {
        update(terminal, terminal_view)
    }
    shutdown(terminal)
}
