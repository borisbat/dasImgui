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
// FEATURE: tooltip_flat — flat-form tooltip widgets (boost v2 §3.2).
// SHOWS:   set_tooltip(text=…) — unconditional tooltip on the hover-stack.
//          set_item_tooltip(text=…) — fires only when the previous widget
//          is hovered (inlines IsItemHovered(ForTooltip) + SetTooltip since
//          ImGui's SetItemTooltip isn't bound to daslang).
//          Each carries a NarrativeState payload with the tooltip copy, so
//          playwright can assert content without driving the cursor over.
// DRIVE:   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
//              | jq '.globals."MAIN_WIN/TOOLTIP_ON_BUTTON"'
// STANDALONE: daslang.exe modules/dasImgui/examples/features/tooltip_flat.das
// LIVE:       daslang-live modules/dasImgui/examples/features/tooltip_flat.das
// =============================================================================

[export]
def init() {
    live_create_window("tooltip_flat — boost v2 §3.2", 720, 360)
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
    window(MAIN_WIN, (text = "set_tooltip / set_item_tooltip",
                      closable = false, flags = ImGuiWindowFlags.None)) {
        text(LEAD, (text = "Hover the button to see set_item_tooltip fire."))
        if (button(HOVER_BTN, (text = "hover me"))) {}
        set_item_tooltip(TOOLTIP_ON_BUTTON, (text = "Fires only while HOVER_BTN is hovered."))

        text(MID, (text = "Unconditional tooltip below — drives a popup any time hover-stack is active."))
        if (button(ALWAYS_BTN, (text = "always-tooltip target"))) {}
        if (IsItemHovered(ImGuiHoveredFlags.None)) {
            set_tooltip(TOOLTIP_ALWAYS, (text = "Fires whenever the surrounding hover gate matches."))
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
