options gen2

require imgui
require imgui/imgui_lint

//! Smoke test — `imgui_lint` is loaded but `_no_imgui_legacy` is NOT set.
//! The lint must stay dormant; a raw imgui::Button call compiles cleanly.

[export]
def main() {
    let _ = Button("opt-out test", float2(0.0f, 0.0f))
}
