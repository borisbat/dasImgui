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
require imgui/imgui_scope_builtin

// =============================================================================
// FEATURE: with_font — Push/PopFont scope wrapper.
// SHOWS:   `with_font(font_ptr) { ... }` switches the active font for every
//          glyph drawn inside. Without a custom font atlas loaded, the demo
//          uses GetFontDefault() — visual change is null but the API surface
//          and AOT shape are exercised. Replace `font_ptr` with a real
//          PushFont target when integrating a multi-font app.
// STANDALONE: daslang.exe modules/dasImgui/examples/features/font_stack.das
// LIVE:       daslang-live modules/dasImgui/examples/features/font_stack.das
// =============================================================================

[export]
def init() {
    live_create_window("with_font — boost v2 §3.6", 720, 360)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(680.0, 300.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "with_font", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text(LEAD, (text = "with_font(GetFont()) is a no-op visually but exercises Push/PopFont."))

        let default_font = GetFont()
        with_font(default_font) {
            text(INSIDE, (text = "inside with_font block — same glyphs since the font matches."))
            if (button(BTN_INSIDE, (text = "button under custom font"))) {}
        }

        separator(SEP)
        text(NOTE, (text = "When a real second font is loaded, swap default_font with the new ImFont? handle."))
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
