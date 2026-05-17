options gen2
options indenting = 4

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

// Module-scope toggles for the Example App panels. A full Examples menu
// wiring (matching imgui_demo.cpp's `ImGui::ShowDemoWindow` Examples
// submenu) waits for the remaining example-app stubs to be ported; for
// now each gets its own checkbox at the bottom of the demo window.
var private SHOW_APP_CONSOLE = false
var private SHOW_APP_LOG = false
var private SHOW_APP_LAYOUT = false
var private SHOW_APP_PROPERTY_EDITOR = false
var private SHOW_APP_LONG_TEXT = false
var private SHOW_APP_AUTO_RESIZE = false
var private SHOW_APP_CONSTRAINED_RESIZE = false
var private SHOW_APP_SIMPLE_OVERLAY = false
var private SHOW_APP_FULLSCREEN = false
var private SHOW_APP_WINDOW_TITLES = false

// Mirrors imgui_demo.cpp:275-6455 — void ImGui::ShowDemoWindow(bool* p_open).
// Renamed to avoid collision with ImGui's built-in ShowDemoWindow binding.
// Phase 2a skeleton: opens the demo window and calls the six Demo-Window
// sub-sections via CollapsingHeader gates. Example-app / tool toggles
// (Examples menu, Tools menu) are wired as section files come online.
def RunImGuiDemo() {
    window(DEMO_WIN, (text = "Dear ImGui Demo (daslang port — Phase 2a skeleton)",
                       closable = false, flags = ImGuiWindowFlags.None)) {
        text("Phase 2a skeleton — 0/24 SECTION blocks ported + 2 example apps (Console, Log).")
        text("Section stubs render below; example apps and meta windows are")
        text("not yet wired into the menu — temporary checkboxes at the bottom")
        text("toggle individual app windows.")
        separator(DEMO_SEP_HEADER)

        ShowDemoWindowWidgets()
        ShowDemoWindowLayout()
        ShowDemoWindowPopups()
        ShowDemoWindowTables()
        ShowDemoWindowColumns()
        ShowDemoWindowInputs()

        separator(DEMO_SEP_FOOTER)
        edit_checkbox(safe_addr(SHOW_APP_CONSOLE),
                      (id = "EXAMPLES_SHOW_CONSOLE", text = "Show Example: Console"))
        edit_checkbox(safe_addr(SHOW_APP_LOG),
                      (id = "EXAMPLES_SHOW_LOG", text = "Show Example: Log"))
        edit_checkbox(safe_addr(SHOW_APP_LAYOUT),
                      (id = "EXAMPLES_SHOW_LAYOUT", text = "Show Example: Simple Layout"))
        edit_checkbox(safe_addr(SHOW_APP_PROPERTY_EDITOR),
                      (id = "EXAMPLES_SHOW_PROPED", text = "Show Example: Property Editor"))
        edit_checkbox(safe_addr(SHOW_APP_LONG_TEXT),
                      (id = "EXAMPLES_SHOW_LONG_TEXT", text = "Show Example: Long Text"))
        edit_checkbox(safe_addr(SHOW_APP_AUTO_RESIZE),
                      (id = "EXAMPLES_SHOW_AUTO_RESIZE", text = "Show Example: Auto-resizing Window"))
        edit_checkbox(safe_addr(SHOW_APP_CONSTRAINED_RESIZE),
                      (id = "EXAMPLES_SHOW_CONSTR_RESIZE", text = "Show Example: Constrained Resize"))
        edit_checkbox(safe_addr(SHOW_APP_SIMPLE_OVERLAY),
                      (id = "EXAMPLES_SHOW_OVERLAY", text = "Show Example: Simple Overlay"))
        edit_checkbox(safe_addr(SHOW_APP_FULLSCREEN),
                      (id = "EXAMPLES_SHOW_FULLSCREEN", text = "Show Example: Fullscreen Window"))
        edit_checkbox(safe_addr(SHOW_APP_WINDOW_TITLES),
                      (id = "EXAMPLES_SHOW_TITLES", text = "Show Example: Manipulating Window Titles"))
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
    if (SHOW_APP_LOG) {
        ShowExampleAppLog()
    }
    // app_small entries — each ShowExampleApp* returns true while open and
    // false when the user clicked X. Mirror the return value back to the
    // toggle so the checkbox stays in sync.
    if (SHOW_APP_LAYOUT && !ShowExampleAppLayout()) {
        SHOW_APP_LAYOUT = false
    }
    if (SHOW_APP_PROPERTY_EDITOR && !ShowExampleAppPropertyEditor()) {
        SHOW_APP_PROPERTY_EDITOR = false
    }
    if (SHOW_APP_LONG_TEXT && !ShowExampleAppLongText()) {
        SHOW_APP_LONG_TEXT = false
    }
    if (SHOW_APP_AUTO_RESIZE && !ShowExampleAppAutoResize()) {
        SHOW_APP_AUTO_RESIZE = false
    }
    if (SHOW_APP_CONSTRAINED_RESIZE && !ShowExampleAppConstrainedResize()) {
        SHOW_APP_CONSTRAINED_RESIZE = false
    }
    if (SHOW_APP_SIMPLE_OVERLAY && !ShowExampleAppSimpleOverlay()) {
        SHOW_APP_SIMPLE_OVERLAY = false
    }
    if (SHOW_APP_FULLSCREEN && !ShowExampleAppFullscreen()) {
        SHOW_APP_FULLSCREEN = false
    }
    // WindowTitles is closable=false in cpp (all 3 windows have nullptr p_open).
    if (SHOW_APP_WINDOW_TITLES) {
        ShowExampleAppWindowTitles()
    }
}
