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

// =============================================================================
// FEATURE: narrative_separator — separator/separator_text/label_text family.
// SHOWS:   separator() — EmptyMarkerState marker, no payload (zero divider).
//          separator_text(text=...) — NarrativeState with rendered title.
//          label_text(key=..., value=...) — two-string display, LabelTextState
//          carries both halves.
// DRIVE:   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
//              | jq '.globals."MAIN_WIN/LABEL_FPS"'
//          # → {"payload":{"key":"frames per second","value":"60"}, ...}
// STANDALONE: daslang.exe modules/dasImgui/examples/features/narrative_separator.das
// LIVE:       daslang-live modules/dasImgui/examples/features/narrative_separator.das
// =============================================================================

[export]
def init() {
    live_create_window("narrative_separator — boost v2 §3.2", 720, 460)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(680.0, 400.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "separator / separator_text / label_text",
                      closable = false, flags = ImGuiWindowFlags.None)) {
        text(LEAD_TEXT, (text = "Three siblings — bare divider, titled divider, two-string row."))
        separator(SEP_AFTER_LEAD)

        separator_text(SECTION_RUNTIME, (text = "Runtime"))
        label_text(LABEL_FPS, (key = "frames per second", value = "60"))
        label_text(LABEL_FRAME, (key = "frame", value = "1234"))
        separator(SEP_BETWEEN)

        separator_text(SECTION_BUILD, (text = "Build"))
        label_text(LABEL_GIT, (key = "commit", value = "abc123 (HEAD)"))
        label_text(LABEL_CFG, (key = "config", value = "Release"))
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
