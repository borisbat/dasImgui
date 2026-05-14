options gen2
options indenting = 4

module app_main_menu

require imgui
require imgui/imgui_boost
require daslib/safe_addr
require daslib/enum_trait

// Module-scope state for ShowExampleMenuFile's "Options" sub-menu. Replaces
// the C++ `static bool/float/int` locals.
var MENU_FILE_ENABLED = true
var MENU_FILE_SLIDER_VALUE = 0.5f
var MENU_FILE_INPUT_VALUE = 0.5f
var MENU_FILE_COMBO_INDEX = 0
var MENU_FILE_OPTIONS_APPEND = true

// Mirrors imgui_demo.cpp:7009-7030 — static void ShowExampleAppMainMenuBar().
def ShowExampleAppMainMenuBar() {
    if (BeginMainMenuBar()) {
        if (BeginMenu("File")) {
            ShowExampleMenuFile()
            EndMenu()
        }
        if (BeginMenu("Edit")) {
            if (MenuItem("Undo", "CTRL+Z")) {}
            // Redo is intentionally disabled here (C++ passes enabled=false).
            if (MenuItem("Redo", "CTRL+Y", false, false)) {}
            Separator()
            if (MenuItem("Cut", "CTRL+X")) {}
            if (MenuItem("Copy", "CTRL+C")) {}
            if (MenuItem("Paste", "CTRL+V")) {}
            EndMenu()
        }
        EndMainMenuBar()
    }
}

// Mirrors imgui_demo.cpp:7034-7113 — static void ShowExampleMenuFile().
// Demonstrates nested menus, recursion ("Recurse.."), child window, slider/
// combo/checkbox inside a menu, the all-style-colors loop with drawlist
// previews, and the "append to an existing menu" idiom.
def ShowExampleMenuFile() {
    MenuItem("(demo menu)", "", false, false)
    if (MenuItem("New")) {}
    if (MenuItem("Open", "Ctrl+O")) {}
    if (BeginMenu("Open Recent")) {
        MenuItem("fish_hat.c")
        MenuItem("fish_hat.inl")
        MenuItem("fish_hat.h")
        if (BeginMenu("More..")) {
            MenuItem("Hello")
            MenuItem("Sailor")
            if (BeginMenu("Recurse..")) {
                ShowExampleMenuFile()
                EndMenu()
            }
            EndMenu()
        }
        EndMenu()
    }
    if (MenuItem("Save", "Ctrl+S")) {}
    if (MenuItem("Save As..")) {}

    Separator()

    if (BeginMenu("Options")) {
        MenuItem("Enabled", "", safe_addr(MENU_FILE_ENABLED))
        BeginChild("child", float2(0.0f, 60.0f), ImGuiChildFlags.Border)
        for (i in range(10)) {
            Text("Scrolling Text {i}")
        }
        EndChild()
        SliderFloat("Value", safe_addr(MENU_FILE_SLIDER_VALUE), 0.0f, 1.0f)
        InputFloat("Input", safe_addr(MENU_FILE_INPUT_VALUE), 0.1f)
        Combo("Combo", safe_addr(MENU_FILE_COMBO_INDEX),
              fixed_array("Yes", "No", "Maybe"))
        EndMenu()
    }

    if (BeginMenu("Colors")) {
        let sz = GetTextLineHeight()
        for (col in type<ImGuiCol>) {
            if (col == ImGuiCol.COUNT) continue
            let name = GetStyleColorName(col)
            let p = GetCursorScreenPos()
            *GetWindowDrawList() |> AddRectFilled(p, float2(p.x + sz, p.y + sz),
                                                  GetColorU32(col))
            Dummy(float2(sz, sz))
            SameLine()
            MenuItem(name)
        }
        EndMenu()
    }

    // Appending again to an existing menu (same label re-opens the menu;
    // ImGui merges the bodies).
    if (BeginMenu("Options")) {
        Checkbox("SomeOption", safe_addr(MENU_FILE_OPTIONS_APPEND))
        EndMenu()
    }

    if (BeginMenu("Disabled", false)) {
        // Body unreachable when BeginMenu returns false; left for parity with
        // the C++ `IM_ASSERT(0)` shape.
        EndMenu()
    }
    if (MenuItem("Checked", "", true)) {}
    Separator()
    if (MenuItem("Quit", "Alt+F4")) {}
}
