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
require daslib/safe_addr

// =============================================================================
// FEATURE: edit_external_toggles — bool / radio / flags on external pointers.
// SHOWS:   edit_checkbox(bool?), edit_radio_button(bool?) (flips on click —
//          ImGui's bool form doesn't mutate, the wrapper does), and
//          edit_checkbox_flags(int?) which toggles a specific bit in a
//          shared int mask.
// DRIVE:   curl -X POST -d '{"name":"imgui_set","args":{"target":"MAIN_WIN/CB_GATE","value":true}}' \
//              localhost:9090/command
// STANDALONE: daslang.exe modules/dasImgui/examples/features/edit_external_toggles.das
// LIVE:       daslang-live modules/dasImgui/examples/features/edit_external_toggles.das
// =============================================================================

var private g_gate : bool = false
var private g_radio : bool = true
var private g_flags : int = 5

[export]
def init() {
    live_create_window("edit_external_toggles — boost v2 §3.7", 720, 380)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(680.0, 320.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "edit_* toggles", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        edit_checkbox(safe_addr(g_gate), (id = "CB_GATE", text = "checkbox (gate)"))
        edit_radio_button(safe_addr(g_radio), (id = "RB_RADIO", text = "radio (flips on click)"))
        separator(SEP)
        text(MASK, (text = "flags mask = {g_flags}"))
        edit_checkbox_flags(safe_addr(g_flags), (id = "CBF_BIT0",
                                                 text = "bit 0 (value 1)", flags_value = 1))
        edit_checkbox_flags(safe_addr(g_flags), (id = "CBF_BIT1",
                                                 text = "bit 1 (value 2)", flags_value = 2))
        edit_checkbox_flags(safe_addr(g_flags), (id = "CBF_BIT2",
                                                 text = "bit 2 (value 4)", flags_value = 4))
        edit_checkbox_flags(safe_addr(g_flags), (id = "CBF_BIT3",
                                                 text = "bit 3 (value 8)", flags_value = 8))
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
