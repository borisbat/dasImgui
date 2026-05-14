options gen2

require imgui
require imgui_app
require glfw/glfw_boost
require opengl/opengl_boost
require live/glfw_live
require live/live_api
require live/live_commands
require live/live_vars
require live/opengl_live
require live_host
require imgui/imgui_live
require imgui/imgui_boost_runtime
require imgui/imgui_boost_v2
require imgui/imgui_widgets_builtin
require imgui/imgui_containers_builtin
require math

// =============================================================================
// FEATURE: progress_bar — ProgressBarState-backed display widget.
// SHOWS:   progress_bar(fraction=…, size=…, overlay=…) emits a payload
//          {fraction, size, overlay}. Animates here by driving fraction off
//          a wall-clock sine so the test can assert non-zero motion.
// DRIVE:   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
//              | jq '.globals."MAIN_WIN/PB_DRIVEN".payload.fraction'
// STANDALONE: daslang.exe modules/dasImgui/examples/features/display_progress.das
// LIVE:       daslang-live modules/dasImgui/examples/features/display_progress.das
// =============================================================================

var private g_t : float = 0.0f

[export]
def init() {
    live_create_window("progress_bar — boost v2 §3.2", 720, 360)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    g_t += 1.0f / 60.0f
    let frac = 0.5f + 0.5f * sin(g_t * 2.0f)

    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(680.0, 300.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "progress_bar", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text(PB_LEAD, (text = "Three progress bars — static, driven, no-overlay."))
        progress_bar(PB_STATIC, (fraction = 0.33f, size = float2(-1.0f, 0.0f),
                                  overlay = "33%"))
        progress_bar(PB_DRIVEN, (fraction = frac, size = float2(-1.0f, 0.0f),
                                  overlay = "{int(frac * 100.0f)}%"))
        progress_bar(PB_PLAIN, (fraction = 0.75f))
    }

    end_of_frame()
    Render()
    var w, h : int
    live_get_framebuffer_size(w, h)
    glViewport(0, 0, w, h)
    glClearColor(0.10f, 0.10f, 0.12f, 1.0f)
    glClear(GL_COLOR_BUFFER_BIT)
    ImGui_ImplOpenGL3_RenderDrawData(GetDrawData())
    live_end_frame()
}

[export]
def shutdown() {
    live_imgui_shutdown()
    live_destroy_window()
}

[export]
def main() {
    init()
    while (!exit_requested()) {
        update()
    }
    shutdown()
}
