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
// FEATURE: narrative_bullet — bullet + bullet_text widgets (boost v2 §3.2).
// SHOWS:   bullet() emits an EmptyMarkerState global (zero-payload, kind="bullet")
//          + bullet_text() emits a NarrativeState with the rendered copy.
//          Together they cover both the standalone marker form (after which
//          `Text` continues on the same line) and the labelled form. Useful
//          for any feature-list / change-log copy that needs telemetry.
// DRIVE:   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
//              | jq '.globals."MAIN_WIN/BULLET_LIST_FAST"'
// STANDALONE: daslang.exe modules/dasImgui/examples/features/narrative_bullet.das
// LIVE:       daslang-live modules/dasImgui/examples/features/narrative_bullet.das
// =============================================================================

[export]
def init() {
    live_create_window("narrative_bullet — boost v2 §3.2", 720, 360)
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
    window(MAIN_WIN, (text = "bullet + bullet_text", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        bullet_text(BULLET_LIST_FAST, (text = "bullet_text(IDENT, (text=...)) — bullet glyph + text together, single telemetry slot."))
        bullet_text(BULLET_LIST_TYPED, (text = "Payload echoes the rendered string under the value field; same shape as text() / text_wrapped()."))
        bullet_text(BULLET_LIST_RELOAD, (text = "Live-reload safe: NarrativeState carries no @live fields beyond the echoed copy."))

        // Standalone bullet marker — emit bullet, then continue with Text on
        // the SAME line. State is empty; payload is `{}`. Use when you need
        // bullet-glyph-then-formatted-line (e.g. inline counters).
        bullet(MARKER_ONE)
        text("plain text after bullet marker — telemetry attaches via auto-emit")
        bullet(MARKER_TWO)
        text("second marker, second tail")
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
