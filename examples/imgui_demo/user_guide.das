options gen2
options indenting = 4

module user_guide

require imgui
require imgui/imgui_scope_builtin

// Mirrors imgui_demo.cpp:6968-6997 — void ImGui::ShowUserGuide().
def ShowUserGuide() {
    let io & = unsafe(GetIO())
    BulletText("Double-click on title bar to collapse window.")
    BulletText("Click and drag on lower corner to resize window\n" +
               "(double-click to auto fit window to its contents).")
    BulletText("CTRL+Click on a slider or drag box to input value as text.")
    BulletText("TAB/SHIFT+TAB to cycle through keyboard editable fields.")
    BulletText("CTRL+Tab to select a window.")
    if (io.FontAllowUserScaling) {
        BulletText("CTRL+Mouse Wheel to zoom window contents.")
    }
    BulletText("While inputing text:\n")
    with_indent(0.0f) {
        BulletText("CTRL+Left/Right to word jump.")
        BulletText("CTRL+A or double-click to select all.")
        BulletText("CTRL+X/C/V to use clipboard cut/copy/paste.")
        BulletText("CTRL+Z,CTRL+Y to undo/redo.")
        BulletText("ESCAPE to revert.")
    }
    BulletText("With keyboard navigation enabled:")
    with_indent(0.0f) {
        BulletText("Arrow keys to navigate.")
        BulletText("Space to activate a widget.")
        BulletText("Return to input text into a widget.")
        BulletText("Escape to deactivate a widget, close popup, exit child window.")
        BulletText("Alt to jump to the menu layer of a window.")
    }
}
