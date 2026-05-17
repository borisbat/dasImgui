options gen2

require imgui
require imgui/imgui_lint

//! Allow-list smoke — default-on lint AND only allow-listed raw calls
//! (`GetIO`, frame lifecycle, style/drawlist queries). Must compile clean.

[export]
def main() {
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.0f
    // Read-only style/drawlist allow-listed since the addition of
    // GetStyleColorName + GetWindowDrawList in ALLOWED_IMGUI.
    let _name = GetStyleColorName(ImGuiCol.Text)
    let _dl = GetWindowDrawList()
    NewFrame()
    EndFrame()
}
