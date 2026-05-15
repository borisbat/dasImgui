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
// FEATURE: edit_external_color — color family on external pointers (boost §3.7).
// SHOWS:   edit_color_edit3/4 + edit_color_picker3/4 against caller-owned
//          float3? / float4? pointers. ColorPicker4 also surfaces an
//          optional [ref] swatch via has_ref_col / ref_col. Payload mirrors
//          the underlying floatN value.
// DRIVE:   curl -X POST -d '{"name":"imgui_set","args":{"target":"MAIN_WIN/CE4","value":{"x":0.8,"y":0.2,"z":0.4,"w":1.0}}}' \
//              localhost:9090/command
// STANDALONE: daslang.exe modules/dasImgui/examples/features/edit_external_color.das
// LIVE:       daslang-live modules/dasImgui/examples/features/edit_external_color.das
// =============================================================================

var private g_rgb : float3 = float3(0.4f, 0.5f, 0.6f)
var private g_rgba : float4 = float4(0.4f, 0.5f, 0.6f, 0.7f)
var private g_pck3 : float3 = float3(0.1f, 0.2f, 0.3f)
var private g_pck4 : float4 = float4(0.1f, 0.2f, 0.3f, 0.4f)

[export]
def init() {
    live_create_window("edit_external_color — boost v2 §3.7", 800, 620)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(760.0, 560.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "edit_* color", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        edit_color_edit3(safe_addr(g_rgb), (id = "CE3", text = "color_edit3 (RGB)"))
        edit_color_edit4(safe_addr(g_rgba), (id = "CE4", text = "color_edit4 (RGBA)"))
        separator(SEP)
        edit_color_picker3(safe_addr(g_pck3), (id = "CP3", text = "color_picker3"))
        edit_color_picker4(safe_addr(g_pck4), (id = "CP4", text = "color_picker4",
                                                flags = ImGuiColorEditFlags.None,
                                                ref_col = float4(1.0f, 0.5f, 0.0f, 1.0f),
                                                has_ref_col = true))
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
