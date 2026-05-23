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

// Mirrors imgui_demo.cpp:275-6455 — void ImGui::ShowDemoWindow(bool* p_open).
// Renamed to avoid collision with ImGui's built-in ShowDemoWindow binding.
//
// The window carries a MenuBar with three sub-menus:
//   Menu     — calls ShowExampleMenuFile() (shared with the modals demos
//              and ShowExampleAppMainMenuBar).
//   Examples — toggles for the 13 mini-app / app windows (Main menu bar +
//              8 small apps + 4 full apps).
//   Tools    — toggles for Metrics / Debug Log / ID Stack / Style Editor /
//              About; each pops its own ImGui-native window via the
//              ShowMetricsWindow / ShowDebugLogWindow / etc. bindings.
//
// Beneath the menubar, the six demo-window section dispatchers render in
// order (Widgets, Layout, Popups, Tables, Columns, Inputs).
//
// All toggle state lives in plain module-scope vars (NOT widget state) so
// the dispatch can read them directly outside the window's body — the
// `edit_menu_item` rail takes a `safe_addr`-owned `bool?` and the Show*
// windows take `bool?` too, so the same address chains through both.

// Examples-menu toggles — 13 entries (1 main menu bar + 8 small + 4 full).
var SHOW_APP_MAIN_MENU_BAR = false
var SHOW_APP_CONSOLE = false
var SHOW_APP_CUSTOM_RENDERING = false
var SHOW_APP_DOCKSPACE = false
var SHOW_APP_DOCUMENTS = false
var SHOW_APP_LOG = false
var SHOW_APP_PROPERTY_EDITOR = false
var SHOW_APP_LAYOUT = false
var SHOW_APP_SIMPLE_OVERLAY = false
var SHOW_APP_AUTO_RESIZE = false
var SHOW_APP_CONSTRAINED_RESIZE = false
var SHOW_APP_FULLSCREEN = false
var SHOW_APP_LONG_TEXT = false
var SHOW_APP_WINDOW_TITLES = false

// Tools-menu toggles — 5 entries pointing at the ImGui-native windows.
var SHOW_TOOL_METRICS = false
var SHOW_TOOL_DEBUG_LOG = false
var SHOW_TOOL_ID_STACK = false
var SHOW_TOOL_STYLE_EDITOR = false
var SHOW_TOOL_ABOUT = false

def RunImGuiDemo() {
    window(DEMO_WIN, (text = "Dear ImGui Demo (daslang port)",
                      closable = false,
                      flags = ImGuiWindowFlags.MenuBar)) {
        menu_bar(DEMO_MENU_BAR) {
            menu(DEMO_MENU_FILE, (text = "Menu", enabled = true)) {
                ShowExampleMenuFile()
            }
            menu(DEMO_MENU_EXAMPLES, (text = "Examples", enabled = true)) {
                edit_menu_item(safe_addr(SHOW_APP_MAIN_MENU_BAR),
                    (id = "EX_MAIN_MENU_BAR", text = "Main menu bar"))
                separator_text(DEMO_EX_SEP_MINI, "Mini apps")
                edit_menu_item(safe_addr(SHOW_APP_CONSOLE),
                    (id = "EX_CONSOLE", text = "Console"))
                edit_menu_item(safe_addr(SHOW_APP_CUSTOM_RENDERING),
                    (id = "EX_CUSTOM_RENDERING", text = "Custom rendering"))
                edit_menu_item(safe_addr(SHOW_APP_DOCKSPACE),
                    (id = "EX_DOCKSPACE", text = "Dockspace"))
                edit_menu_item(safe_addr(SHOW_APP_DOCUMENTS),
                    (id = "EX_DOCUMENTS", text = "Documents"))
                edit_menu_item(safe_addr(SHOW_APP_LOG),
                    (id = "EX_LOG", text = "Log"))
                edit_menu_item(safe_addr(SHOW_APP_PROPERTY_EDITOR),
                    (id = "EX_PROP_ED", text = "Property editor"))
                edit_menu_item(safe_addr(SHOW_APP_LAYOUT),
                    (id = "EX_LAYOUT", text = "Simple layout"))
                edit_menu_item(safe_addr(SHOW_APP_SIMPLE_OVERLAY),
                    (id = "EX_OVERLAY", text = "Simple overlay"))
                separator_text(DEMO_EX_SEP_CONCEPTS, "Concepts")
                edit_menu_item(safe_addr(SHOW_APP_AUTO_RESIZE),
                    (id = "EX_AUTO_RESIZE", text = "Auto-resizing window"))
                edit_menu_item(safe_addr(SHOW_APP_CONSTRAINED_RESIZE),
                    (id = "EX_CONSTR_RESIZE", text = "Constrained-resizing window"))
                edit_menu_item(safe_addr(SHOW_APP_FULLSCREEN),
                    (id = "EX_FULLSCREEN", text = "Fullscreen window"))
                edit_menu_item(safe_addr(SHOW_APP_LONG_TEXT),
                    (id = "EX_LONG_TEXT", text = "Long text display"))
                edit_menu_item(safe_addr(SHOW_APP_WINDOW_TITLES),
                    (id = "EX_WIN_TITLES", text = "Manipulating window titles"))
            }
            menu(DEMO_MENU_TOOLS, (text = "Tools", enabled = true)) {
                edit_menu_item(safe_addr(SHOW_TOOL_METRICS),
                    (id = "TOOL_METRICS", text = "Metrics/Debugger"))
                edit_menu_item(safe_addr(SHOW_TOOL_DEBUG_LOG),
                    (id = "TOOL_DEBUG_LOG", text = "Debug Log"))
                edit_menu_item(safe_addr(SHOW_TOOL_ID_STACK),
                    (id = "TOOL_ID_STACK", text = "ID Stack Tool"))
                edit_menu_item(safe_addr(SHOW_TOOL_STYLE_EDITOR),
                    (id = "TOOL_STYLE_ED", text = "Style Editor"))
                separator(DEMO_TOOLS_SEP)
                edit_menu_item(safe_addr(SHOW_TOOL_ABOUT),
                    (id = "TOOL_ABOUT", text = "About Dear ImGui"))
            }
        }

        ShowDemoWindowWidgets()
        ShowDemoWindowLayout()
        ShowDemoWindowPopups()
        ShowDemoWindowTables()
        ShowDemoWindowColumns()
        ShowDemoWindowInputs()
    }

    // Example-app windows live OUTSIDE the demo window — each opens its own.
    if (SHOW_APP_MAIN_MENU_BAR) {
        ShowExampleAppMainMenuBar()
    }
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
    // toggle so the menu check-mark stays in sync.
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
    if (SHOW_APP_CUSTOM_RENDERING && !ShowExampleAppCustomRendering()) {
        SHOW_APP_CUSTOM_RENDERING = false
    }
    if (SHOW_APP_DOCKSPACE && !ShowExampleAppDockSpace()) {
        SHOW_APP_DOCKSPACE = false
    }
    if (SHOW_APP_DOCUMENTS && !ShowExampleAppDocuments()) {
        SHOW_APP_DOCUMENTS = false
    }

    // Tools menu — each Show*Window mutates its bool? when the user clicks X
    // on the tool window's titlebar, so the menu check-mark auto-syncs.
    if (SHOW_TOOL_METRICS) {
        ShowMetricsWindow(safe_addr(SHOW_TOOL_METRICS))
    }
    if (SHOW_TOOL_DEBUG_LOG) {
        ShowDebugLogWindow(safe_addr(SHOW_TOOL_DEBUG_LOG))
    }
    if (SHOW_TOOL_ID_STACK) {
        ShowIDStackToolWindow(safe_addr(SHOW_TOOL_ID_STACK))
    }
    if (SHOW_TOOL_STYLE_EDITOR) {
        window(DEMO_STYLE_ED_WIN, (text = "Dear ImGui Style Editor",
                                    closable = true,
                                    flags = ImGuiWindowFlags.None)) {
            style_editor::ShowStyleEditor()
        }
        // Style Editor uses [container] WindowState — close via window's X
        // flips DEMO_STYLE_ED_WIN.open false; mirror back to the toggle.
        if (!DEMO_STYLE_ED_WIN.open) {
            SHOW_TOOL_STYLE_EDITOR = false
            DEMO_STYLE_ED_WIN.open = true
        }
    }
    if (SHOW_TOOL_ABOUT) {
        ShowAboutWindow(safe_addr(SHOW_TOOL_ABOUT))
    }
}
