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
// FEATURE: display_image — image() widget against the ImGui font atlas texture.
// SHOWS:   ImageState payload carries size / uv0 / uv1 / tint_col / border_col
//          plus tex_id_int (reinterpret of texture handle as uint64 for
//          snapshot readability). Uses the font atlas texture from
//          GetIO().Fonts.TexID since dasImgui standalone has no built-in
//          image loader; swap for any real texture handle on application
//          integration.
// DRIVE:   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
//              | jq '.globals."MAIN_WIN/IMG_BASIC".payload'
// STANDALONE: daslang.exe modules/dasImgui/examples/features/display_image.das
// LIVE:       daslang-live modules/dasImgui/examples/features/display_image.das
// =============================================================================

[export]
def init() {
    live_create_window("display_image — boost v2 §3.2", 720, 420)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(680.0, 360.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "image() against font atlas",
                      closable = false, flags = ImGuiWindowFlags.None)) {
        let io & = unsafe(GetIO())
        let font_tex = io.Fonts.TexID
        if (font_tex == null) {
            text(LEAD, (text = "Font atlas not yet built — wait for first frame."))
        } else {
            text(LEAD, (text = "Three image() calls against the same atlas — varying size, uv, tint."))
            image(IMG_BASIC, (texture = font_tex,
                              size = float2(128.0f, 128.0f),
                              uv0 = float2(0.0f, 0.0f),
                              uv1 = float2(1.0f, 1.0f),
                              tint_col = float4(1.0f, 1.0f, 1.0f, 1.0f),
                              border_col = float4(0.0f, 0.0f, 0.0f, 0.0f)))
            same_line(GAP)
            image(IMG_HALF, (texture = font_tex,
                             size = float2(96.0f, 96.0f),
                             uv0 = float2(0.0f, 0.0f),
                             uv1 = float2(0.5f, 0.5f),
                             tint_col = float4(1.0f, 0.5f, 0.5f, 1.0f),
                             border_col = float4(0.0f, 0.0f, 0.0f, 0.0f)))
            same_line(GAP2)
            image(IMG_TINTED, (texture = font_tex,
                               size = float2(64.0f, 64.0f),
                               uv0 = float2(0.0f, 0.0f),
                               uv1 = float2(1.0f, 1.0f),
                               tint_col = float4(0.0f, 0.95f, 0.5f, 1.0f),
                               border_col = float4(1.0f, 1.0f, 1.0f, 1.0f)))
        }
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
