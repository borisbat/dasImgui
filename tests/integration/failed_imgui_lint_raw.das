options gen2
options _no_imgui_legacy = true

require imgui
require imgui/imgui_lint

//! Negative test — `_no_imgui_legacy = true` + raw `imgui::Button` must
//! trip IMGUI002 (runtime_macro error code 50503).

expect 50503

[export]
def main() {
    let _ = Button("must fail with IMGUI002", float2(0.0f, 0.0f))
}
