options gen2
options indenting = 4

module imgui_demo

require imgui public
require imgui/imgui_widgets_builtin public
require imgui/imgui_containers_builtin public
require imgui/imgui_boost_v2 public

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

// Mirrors imgui_demo.cpp:275-6455 — void ImGui::ShowDemoWindow(bool* p_open).
// Renamed to avoid collision with ImGui's built-in ShowDemoWindow binding.
// Phase 2a skeleton: opens the demo window and calls the six Demo-Window
// sub-sections via CollapsingHeader gates. Example-app / tool toggles
// (Examples menu, Tools menu) are wired as section files come online.
def RunImGuiDemo() {
    window(DEMO_WIN, (text = "Dear ImGui Demo (daslang port — Phase 2a skeleton)",
                       closable = false, flags = ImGuiWindowFlags.None)) {
        Text("Phase 2a skeleton — 0/24 SECTION blocks ported.")
        Text("Section stubs render below; example apps and meta windows are")
        Text("not yet wired into the menu.")
        Separator()

        ShowDemoWindowWidgets()
        ShowDemoWindowLayout()
        ShowDemoWindowPopups()
        ShowDemoWindowTables()
        ShowDemoWindowColumns()
        ShowDemoWindowInputs()
    }
}

// Tooltip helper used across all sections. Mirrors imgui_demo.cpp:181-191
// HelpMarker(). Public so any section file can use it without redefining.
def HelpMarker(desc : string) {
    TextDisabled("(?)")
    if (IsItemHovered()) {
        BeginTooltip()
        PushTextWrapPos(GetFontSize() * 35.0)
        TextUnformatted(desc)
        PopTextWrapPos()
        EndTooltip()
    }
}
