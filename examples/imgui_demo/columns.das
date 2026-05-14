options gen2
options indenting = 4

module columns

require imgui

// Mirrors imgui_demo.cpp:6045-6248 — static void ShowDemoWindowColumns().
def ShowDemoWindowColumns() {
    if (CollapsingHeader("Columns (legacy API)")) {
        Text("TODO: port section (imgui_demo.cpp:6045-6248)")
    }
}
