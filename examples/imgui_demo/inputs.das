options gen2
options indenting = 4

module inputs

require imgui

// Mirrors imgui_demo.cpp:6249-6455 — static void ShowDemoWindowInputs().
def ShowDemoWindowInputs() {
    if (CollapsingHeader("Inputs & Keyboard/Mouse/Gamepad")) {
        Text("TODO: port section (imgui_demo.cpp:6249-6455)")
    }
}
