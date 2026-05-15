options gen2
options _no_imgui_legacy = true

require imgui
require imgui/imgui_lint

//! Allow-list smoke — `_no_imgui_legacy = true` AND only allow-listed raw
//! calls (`GetIO`, frame lifecycle). Must compile clean.

[export]
def main() {
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.0f
    NewFrame()
    EndFrame()
}
