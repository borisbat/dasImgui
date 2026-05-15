options gen2
options indenting = 4
options _allow_imgui_legacy = true

module imgui_demo

require imgui public
require imgui/imgui_widgets_builtin public
require imgui/imgui_containers_builtin public
require imgui/imgui_boost_v2 public
require daslib/safe_addr

require widgets public
require layout public
require popups public
require tables public
require columns public
require inputs public
require about public
require style_editor public
require user_guide public
require app_main_menu public
require app_console public
require app_log public
require app_custom_rendering public
require app_dockspace public
require app_documents public
require app_small public

// Module-scope toggle for the Example App: Console panel. A full Examples
// menu wiring (matching imgui_demo.cpp's `ImGui::ShowDemoWindow` Examples
// submenu) waits for the other example-app stubs to be ported; for now
// the Console gets a single checkbox at the bottom of the demo window.
var private SHOW_APP_CONSOLE = false

// Mirrors imgui_demo.cpp:275-6455 — void ImGui::ShowDemoWindow(bool* p_open).
// Renamed to avoid collision with ImGui's built-in ShowDemoWindow binding.
// Phase 2a skeleton: opens the demo window and calls the six Demo-Window
// sub-sections via CollapsingHeader gates. Example-app / tool toggles
// (Examples menu, Tools menu) are wired as section files come online.
def RunImGuiDemo() {
    window(DEMO_WIN, (text = "Dear ImGui Demo (daslang port — Phase 2a skeleton)",
                       closable = false, flags = ImGuiWindowFlags.None)) {
        Text("Phase 2a skeleton — 0/24 SECTION blocks ported + 1 example app (Console).")
        Text("Section stubs render below; example apps and meta windows are")
        Text("not yet wired into the menu — temporary checkboxes at the bottom")
        Text("toggle individual app windows.")
        Separator()

        ShowDemoWindowWidgets()
        ShowDemoWindowLayout()
        ShowDemoWindowPopups()
        ShowDemoWindowTables()
        ShowDemoWindowColumns()
        ShowDemoWindowInputs()

        Separator()
        edit_checkbox(safe_addr(SHOW_APP_CONSOLE),
                      (id = "EXAMPLES_SHOW_CONSOLE", text = "Show Example: Console"))
    }

    // Example-app windows live OUTSIDE the demo window — each opens its own.
    if (SHOW_APP_CONSOLE) {
        ShowExampleAppConsole()
        // Console's "Close Console" title-bar context menu sets an internal
        // flag; consume it here to flip our visibility toggle off so the
        // window goes away on the next frame.
        if (take_close_request()) {
            SHOW_APP_CONSOLE = false
        }
    }
}
