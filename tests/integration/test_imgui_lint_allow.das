options gen2

require imgui
require imgui/imgui_lint

//! Allow-list smoke — default-on lint AND only allow-listed raw calls
//! (`GetIO`, frame lifecycle, style queries). Must compile clean.

[export]
def main() {
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.0f
    // Read-only style allow-listed via GetStyleColorName in ALLOWED_IMGUI.
    // Drawlist queries (GetWindowDrawList / AddRect / AddRectFilled / AddLine /
    // GetForegroundDrawList) were dropped from ALLOWED_IMGUI by PR-B1 in favor
    // of the with_*_drawlist rail.
    let _name = GetStyleColorName(ImGuiCol.Text)
    NewFrame()
    EndFrame()
}
