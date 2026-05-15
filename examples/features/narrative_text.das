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
// FEATURE: narrative_text — telemetry-bearing text widgets (boost v2 §3.2).
// SHOWS:   text / text_unformatted / text_wrapped / text_colored / text_disabled
//          all auto-emit NarrativeState globals and serialize through to
//          imgui_snapshot. Each call site shows up under MAIN_WIN/<IDENT> with
//          payload {value: "<echoed text>"} — the precondition for any
//          playwright test that needs to assert on the rendered copy. The raw
//          `Text(s)` form has NO telemetry and is invisible to imgui_snapshot;
//          this demo's whole point is the boost wrappers above.
// DRIVE:   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
//              | jq '.globals."MAIN_WIN/NARRATIVE_LEAD"'
//          # → {"payload":{"value":"Telemetry-bearing narrative…"}, "kind":"text", ...}
// STANDALONE: daslang.exe modules/dasImgui/examples/features/narrative_text.das
// LIVE:       daslang-live modules/dasImgui/examples/features/narrative_text.das
// =============================================================================

[export]
def init() {
    live_create_window("narrative_text — boost v2 §3.2", 760, 460)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()

    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(720.0, 400.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "narrative widgets", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text(NARRATIVE_LEAD, (text = "Telemetry-bearing narrative — each line emits its rendered string back as payload value under its IDENT."))
        text_unformatted(NARRATIVE_UNFORMATTED, (text = "text_unformatted: %s passes through literally — no printf parse."))
        text_wrapped(NARRATIVE_WRAPPED, (text = "text_wrapped soft-wraps at the window edge instead of clipping. Useful for any paragraph copy that needs to flow with the user's column width — release notes, tooltips, help panels."))
        text_colored(NARRATIVE_COLORED, (color = float4(0.95f, 0.65f, 0.20f, 1.0f), text = "text_colored: per-call color, payload mirrors the rendered string."))
        text_disabled(NARRATIVE_DISABLED, (text = "text_disabled: dimmed style for caption / hint copy."))
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
