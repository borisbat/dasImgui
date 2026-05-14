options gen2
options indenting = 4

module app_main_menu

require imgui
require imgui/imgui_widgets_builtin
require imgui/imgui_containers_builtin
require daslib/safe_addr
require daslib/enum_trait

// Module-scope free globals — backing store for the raw-imgui widgets that
// remain inside menus (SliderFloat / InputFloat / Checkbox). The menu_bar /
// menu / menu_item / combo calls go through the v2 boost surface; the
// other raw widgets aren't part of the v1-removal scope (see commit msg).
var MENU_FILE_SLIDER_VALUE = 0.5f
var MENU_FILE_INPUT_VALUE = 0.5f
var MENU_FILE_OPTIONS_APPEND = true

// Indexed widget table for the "Colors" submenu loop (one menu_item per
// ImGuiCol entry). `[widget]` macros do not auto-emit table globals — the
// indexed form requires the table declared at module scope.
var private FILE_COLORS_ITEM : table<int; ToggleState>

// Mirrors imgui_demo.cpp:7009-7030 — static void ShowExampleAppMainMenuBar().
// `BeginMainMenuBar` has no v2 boost equivalent yet (only `menu_bar`, which
// requires an enclosing window with the `MenuBar` flag) — stays raw.
def ShowExampleAppMainMenuBar() {
    if (BeginMainMenuBar()) {
        menu(APP_MENU_FILE, (text = "File", enabled = true)) {
            ShowExampleMenuFile()
        }
        menu(APP_MENU_EDIT, (text = "Edit", enabled = true)) {
            if (menu_item(EDIT_UNDO, (text = "Undo", shortcut = "CTRL+Z"))) {}
            // v2 gap: menu_item has no `enabled` arg (mouse card
            // `dasimgui-menu-item-boost-signature-no-selected-no-enabled`).
            // C++ passes enabled=false to show the disabled visual; raw here.
            if (MenuItem("Redo", "CTRL+Y", false, false)) {}
            Separator()
            if (menu_item(EDIT_CUT, (text = "Cut", shortcut = "CTRL+X"))) {}
            if (menu_item(EDIT_COPY, (text = "Copy", shortcut = "CTRL+C"))) {}
            if (menu_item(EDIT_PASTE, (text = "Paste", shortcut = "CTRL+V"))) {}
        }
        EndMainMenuBar()
    }
}

// Mirrors imgui_demo.cpp:7034-7113 — static void ShowExampleMenuFile().
// Demonstrates nested menus, recursion ("Recurse.."), child window, slider/
// combo/checkbox inside a menu, the all-style-colors loop with drawlist
// previews, and the "append to an existing menu" idiom.
def ShowExampleMenuFile() {
    // v2 gap: menu_item lacks selected/enabled. C++ uses these as a static
    // section-header label (selected=false, enabled=false). Raw.
    MenuItem("(demo menu)", "", false, false)
    if (menu_item(FILE_NEW, (text = "New"))) {}
    if (menu_item(FILE_OPEN, (text = "Open", shortcut = "Ctrl+O"))) {}
    menu(FILE_OPEN_RECENT, (text = "Open Recent", enabled = true)) {
        menu_item(FILE_FISH_C, (text = "fish_hat.c"))
        menu_item(FILE_FISH_INL, (text = "fish_hat.inl"))
        menu_item(FILE_FISH_H, (text = "fish_hat.h"))
        menu(FILE_MORE, (text = "More..", enabled = true)) {
            menu_item(FILE_HELLO, (text = "Hello"))
            menu_item(FILE_SAILOR, (text = "Sailor"))
            // The Recurse submenu re-enters ShowExampleMenuFile. Inside the
            // recursion every [widget] state global aliases the outer call's
            // (same module-scope identifier) — fine for the demo since
            // ImGui's max-depth limit gates the dropdown and no test reads
            // per-level state.
            menu(FILE_RECURSE, (text = "Recurse..", enabled = true)) {
                ShowExampleMenuFile()
            }
        }
    }
    if (menu_item(FILE_SAVE, (text = "Save", shortcut = "Ctrl+S"))) {}
    if (menu_item(FILE_SAVE_AS, (text = "Save As.."))) {}

    Separator()

    menu(FILE_OPTIONS_A, (text = "Options", enabled = true)) {
        // Persistent toggle — ToggleState.value carries the checked state.
        menu_item(FILE_OPTIONS_ENABLED, (text = "Enabled", init = true))
        BeginChild("child", float2(0.0f, 60.0f), ImGuiChildFlags.Border)
        for (i in range(10)) {
            Text("Scrolling Text {i}")
        }
        EndChild()
        // Raw SliderFloat / InputFloat — out of menu_bar/menu/menu_item
        // migration scope; v2 boost equivalents exist (slider_float /
        // input_float) but converting them is a separate consistency pass.
        SliderFloat("Value", safe_addr(MENU_FILE_SLIDER_VALUE), 0.0f, 1.0f)
        InputFloat("Input", safe_addr(MENU_FILE_INPUT_VALUE), 0.1f)
        combo(MENU_FILE_COMBO, (text = "Combo",
                                items <- ["Yes", "No", "Maybe"]))
    }

    menu(FILE_COLORS, (text = "Colors", enabled = true)) {
        let sz = GetTextLineHeight()
        for (col in type<ImGuiCol>) {
            if (col == ImGuiCol.COUNT) continue
            let name = GetStyleColorName(col)
            let p = GetCursorScreenPos()
            *GetWindowDrawList() |> AddRectFilled(p, float2(p.x + sz, p.y + sz),
                                                  GetColorU32(col))
            Dummy(float2(sz, sz))
            SameLine()
            menu_item(FILE_COLORS_ITEM[int(col)], (text = name))
        }
    }

    // Appending again to an existing menu (same label re-opens the merged
    // body in ImGui). DIFFERENT ident than FILE_OPTIONS_A so the v2 state
    // globals don't collide.
    menu(FILE_OPTIONS_B, (text = "Options", enabled = true)) {
        // Raw Checkbox — out of scope (see comment above on slider/input).
        Checkbox("SomeOption", safe_addr(MENU_FILE_OPTIONS_APPEND))
    }

    menu(FILE_DISABLED, (text = "Disabled", enabled = false)) {
        // Body unreachable while enabled=false; left for parity with the
        // C++ `IM_ASSERT(0)` shape.
    }
    // v2 gap: menu_item lacks the static-selected arg. C++ passes
    // selected=true to render a permanent check mark next to "Checked".
    if (MenuItem("Checked", "", true)) {}
    Separator()
    if (menu_item(FILE_QUIT, (text = "Quit", shortcut = "Alt+F4"))) {}
}
