options gen2
options gc
options persistent_heap

require imgui/imgui_harness
require imgui/imgui_terminal
require daslib/safe_addr
require math
require strings

var private g_terminal : Terminal
var private g_terminal_view = ImGuiTerminalState()
var private g_zoom_percent = 150

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
    harness_maximize_window()
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
    GetStyle().FontScaleMain = float(g_zoom_percent) / 100.0f
    let viewport = GetMainViewport()
    SetNextWindowPos(viewport.WorkPos, ImGuiCond.Always)
    SetNextWindowSize(viewport.WorkSize, ImGuiCond.Always)
    window(TERMINAL_WIN, (text = "dasHerd terminal", closable = false,
            flags = ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoMove)) {
        let io & = unsafe(GetIO())
        if (IsWindowHovered(ImGuiHoveredFlags.RootAndChildWindows) && io.KeyCtrl) {
            if (io.MouseWheel > 0.0f) {
                g_zoom_percent = min(g_zoom_percent + 10, 300)
            } elif (io.MouseWheel < 0.0f) {
                g_zoom_percent = max(g_zoom_percent - 10, 50)
            }
        }
        text("Zoom")
        same_line()
        SetNextItemWidth(180.0f)
        if (edit_slider_int(safe_addr(g_zoom_percent),
                (id = "TERMINAL_ZOOM_SLIDER", text = "##zoom", v_min = 50,
                 v_max = 300, format = "%d%%"))) {
            g_zoom_percent = clamp(((g_zoom_percent + 5) / 10) * 10, 50, 300)
        }
        same_line()
        if (small_button(TERMINAL_ZOOM_RESET, (text = "100%"))) {
            g_zoom_percent = 100
        }
        text_show(TERMINAL_ZOOM, "{g_zoom_percent}")
        separator()
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
