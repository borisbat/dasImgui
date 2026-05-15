options gen2
options indenting = 4
options _allow_imgui_legacy = true

module tables

require imgui

// Mirrors imgui_demo.cpp:4154-6044 — static void ShowDemoWindowTables().
def ShowDemoWindowTables() {
    if (CollapsingHeader("Tables & Columns")) {
        Text("TODO: port section (imgui_demo.cpp:4154-6044)")
    }
}
