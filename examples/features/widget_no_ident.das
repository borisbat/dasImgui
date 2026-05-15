options gen2
// This demo deliberately exercises the Form 2 named-tuple-without-ident shape
// that STYLE001 forbids on single-arg narrative widgets like `text`. Opt out
// per-file so the educational `text((text=...))` line below renders instead
// of becoming a hard build error.
options _allow_imgui_legacy = true

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
// FEATURE: widget_no_ident — smoke of the three [widget] call forms.
// SHOWS:   1. EXPLICIT  text(IDENT, (text=...))     — leading ident
//          2. AUTO-GEN  text((text=...))            — first arg is named-tuple
//          3. POSITIONAL text("string")             — single-string sugar
// =============================================================================

[export]
def init() {
    live_create_window("widget_no_ident smoke", 720, 360)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(640.0, 300.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "no-ident forms",
                      closable = false, flags = ImGuiWindowFlags.None)) {
        // Form 1: explicit ident.
        text(EXPLICIT_HELLO, (text = "explicit ident form"))

        // Form 2: no-ident named-tuple. Synthesized state global is internal;
        // user can't read .value (not that text has a useful one anyway).
        text((text = "no-ident named-tuple form"))

        // Form 3: positional-string sugar (single-string text family only).
        text("positional-string form")
        text_unformatted("text_unformatted positional form")
        text_wrapped("text_wrapped positional form — long enough to wrap and exercise the auto-emit across a reflow")
        text_disabled("text_disabled positional form")
        bullet_text("bullet_text positional form")
        separator_text("separator_text positional form")
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
