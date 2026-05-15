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
// FEATURE: main_menu_bar — top-level menu container (boost v2 §3.3).
// SHOWS:   main_menu_bar { menu(...) { menu_item(...) } } — screen-top bar,
//          distinct from window-attached menu_bar. The container emits a
//          MainMenuBarState global, and the children's idents nest under
//          MAIN_MENU/<menu>/<item> path keys. Click an item via imgui_click
//          to toggle its check state.
// DRIVE:   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
//              | jq '.globals|keys|map(select(startswith("MAIN_MENU_BAR/")))'
//          curl -X POST -d '{"name":"imgui_click","args":{"target":"MAIN_MENU_BAR/FILE_MENU/MI_SAVE"}}' \
//              localhost:9090/command
// STANDALONE: daslang.exe modules/dasImgui/examples/features/menu_main.das
// LIVE:       daslang-live modules/dasImgui/examples/features/menu_main.das
// =============================================================================

[export]
def init() {
    live_create_window("main_menu_bar — boost v2 §3.3", 720, 360)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    main_menu_bar(MAIN_MENU_BAR) {
        menu(FILE_MENU, (text = "File", enabled = true)) {
            menu_item(MI_SAVE, (text = "Save", shortcut = "Ctrl+S"))
            menu_item(MI_RELOAD, (text = "Reload", shortcut = "Ctrl+R"))
            separator(FILE_SEP)
            menu_item(MI_QUIT, (text = "Quit", shortcut = "Ctrl+Q"))
        }
        menu(VIEW_MENU, (text = "View", enabled = true)) {
            menu_item(MI_GRID, (text = "Grid"))
            menu_item(MI_RULER, (text = "Ruler"))
        }
    }

    SetNextWindowPos(ImVec2(60.0, 60.0), ImGuiCond.Always)
    SetNextWindowSize(ImVec2(620.0, 220.0), ImGuiCond.Always)
    window(BODY, (text = "main_menu_bar body", closable = false,
                  flags = ImGuiWindowFlags.None)) {
        text(BODY_LEAD, (text = "Top-bar is the main_menu_bar above; this window is unrelated."))
        text(BODY_SAVE, (text = "Save toggled: {MI_SAVE.value}"))
        text(BODY_RELOAD, (text = "Reload toggled: {MI_RELOAD.value}"))
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
