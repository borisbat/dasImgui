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
require imgui/imgui_visual_aids

// =============================================================================
// FEATURE: imgui_synth_keys — ImGui-bypass synthetic keyboard driver.
// SHOWS:   `imgui_key_press` / `imgui_key_release` / `imgui_key_char` /
//          `imgui_key_type` / `imgui_key_chord` / `imgui_key_play` live
//          commands inject events directly into ImGui's input queue,
//          skipping the GLFW backend chain. Ctrl-shortcuts (Ctrl+A etc.)
//          route correctly after a synth click — the bypass purges
//          backend events that would otherwise poison Shortcut() routing.
// DRIVE:   curl -X POST -d '{"name":"imgui_key_type","args":{"text":"Hello, World!","total_duration_s":3.0}}' \
//              localhost:9090/command
//          curl -X POST -d '{"name":"imgui_key_chord","args":{"mods":["Ctrl"],"key":"A"}}' \
//              localhost:9090/command
// STANDALONE: daslang.exe modules/dasImgui/examples/features/imgui_synth_keys.das
// LIVE:       daslang-live modules/dasImgui/examples/features/imgui_synth_keys.das
// =============================================================================

[export]
def init() {
    live_create_window("imgui_synth_keys", 720, 320)
    live_imgui_init(live_window)
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.5
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()

    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    apply_synth_io_override()    // dispatches imgui_synth_tick — purges
                                 // backend events and injects synth state.
    NewFrame()

    SetNextWindowPos(ImVec2(40.0, 40.0), ImGuiCond.Always)
    SetNextWindowSize(ImVec2(640.0, 240.0), ImGuiCond.Always)
    if (Begin("synth keys demo (imgui bypass)", null, ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoMove)) {
        Text("Drive `imgui_key_type`, `imgui_key_chord`, `imgui_key_play` to feed the input below.")
        Text("Use `imgui_focus` to put keyboard focus on NAME_INPUT first.")
        input_text(NAME_INPUT, (text = "Name"))
        Text("buffer = {NAME_INPUT.value}")
        Text("Ctrl held: {IsKeyDown(ImGuiKey.LeftCtrl) || IsKeyDown(ImGuiKey.RightCtrl)}")
        Text("Shift held: {IsKeyDown(ImGuiKey.LeftShift) || IsKeyDown(ImGuiKey.RightShift)}")
    }
    End()

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
