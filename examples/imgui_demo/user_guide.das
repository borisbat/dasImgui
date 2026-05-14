options gen2
options indenting = 4

module user_guide

require imgui
require imgui/imgui_widgets_builtin
require imgui/imgui_scope_builtin

// Mirrors imgui_demo.cpp:6968-6997 — void ImGui::ShowUserGuide().
def ShowUserGuide() {
    let io & = unsafe(GetIO())
    bullet_text(GUIDE_BULLET_TEXT_1, (text = "Double-click on title bar to collapse window."))
    bullet_text(GUIDE_BULLET_TEXT_2, (text = "Click and drag on lower corner to resize window\n" +
                                             "(double-click to auto fit window to its contents)."))
    bullet_text(GUIDE_BULLET_TEXT_3, (text = "CTRL+Click on a slider or drag box to input value as text."))
    bullet_text(GUIDE_BULLET_TEXT_4, (text = "TAB/SHIFT+TAB to cycle through keyboard editable fields."))
    bullet_text(GUIDE_BULLET_TEXT_5, (text = "CTRL+Tab to select a window."))
    if (io.FontAllowUserScaling) {
        bullet_text(GUIDE_BULLET_TEXT_6, (text = "CTRL+Mouse Wheel to zoom window contents."))
    }
    bullet_text(GUIDE_BULLET_TEXT_7, (text = "While inputing text:\n"))
    with_indent(0.0f) {
        bullet_text(GUIDE_BULLET_TEXT_8, (text = "CTRL+Left/Right to word jump."))
        bullet_text(GUIDE_BULLET_TEXT_9, (text = "CTRL+A or double-click to select all."))
        bullet_text(GUIDE_BULLET_TEXT_10, (text = "CTRL+X/C/V to use clipboard cut/copy/paste."))
        bullet_text(GUIDE_BULLET_TEXT_11, (text = "CTRL+Z,CTRL+Y to undo/redo."))
        bullet_text(GUIDE_BULLET_TEXT_12, (text = "ESCAPE to revert."))
    }
    bullet_text(GUIDE_BULLET_TEXT_13, (text = "With keyboard navigation enabled:"))
    with_indent(0.0f) {
        bullet_text(GUIDE_BULLET_TEXT_14, (text = "Arrow keys to navigate."))
        bullet_text(GUIDE_BULLET_TEXT_15, (text = "Space to activate a widget."))
        bullet_text(GUIDE_BULLET_TEXT_16, (text = "Return to input text into a widget."))
        bullet_text(GUIDE_BULLET_TEXT_17, (text = "Escape to deactivate a widget, close popup, exit child window."))
        bullet_text(GUIDE_BULLET_TEXT_18, (text = "Alt to jump to the menu layer of a window."))
    }
}
