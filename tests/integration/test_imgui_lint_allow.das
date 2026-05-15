options gen2

require imgui
require imgui/imgui_lint

//! Allow-list smoke — default-on lint AND only allow-listed raw calls
//! (`GetIO`, frame lifecycle). Must compile clean.

[export]
def main() {
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.0f
    NewFrame()
    EndFrame()
}
