options gen2
options _no_imgui_legacy = true

require imgui
require imgui/imgui_lint
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
// FEATURE: popup_context_item — [container] for BeginPopupContextItem/EndPopup.
//          Right-click context menu attached to the previously submitted item.
//          ImGui drives open/close internally — no pending_open/close.
// SHOWS:   right-click any TARGET_BTN row to open its action menu; selected
//          action increments PICKED counter and updates LAST_ACTION text.
// STANDALONE: daslang.exe modules/dasImgui/examples/features/popup_context_item.das
// LIVE:       daslang-live modules/dasImgui/examples/features/popup_context_item.das
// =============================================================================

var LAST_ACTION : string = "(none yet)"

[export]
def init() {
    live_create_window("popup_context_item — container", 640, 480)
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
    NewFrame()

    SetNextWindowSize(ImVec2(580.0, 420.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "popup_context_item", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text("Right-click the button below to open its context menu.")

        if (button(TARGET_BTN, (text = "Right-click me"))) {
            LAST_ACTION = "(left-click ignored)"
        }
        popup_context_item(TARGET_CTX, (str_id = "target_ctx",
                                        flags = ImGuiPopupFlags.MouseButtonRight)) {
            if (menu_item(ACTION_RENAME, (text = "Rename", shortcut = "F2"))) {
                LAST_ACTION = "Rename"
            }
            if (menu_item(ACTION_DELETE, (text = "Delete", shortcut = "Del"))) {
                LAST_ACTION = "Delete"
            }
            separator()
            if (menu_item(ACTION_INFO, (text = "Info", shortcut = ""))) {
                LAST_ACTION = "Info"
            }
        }

        separator()
        text("Last action: {LAST_ACTION}")
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
