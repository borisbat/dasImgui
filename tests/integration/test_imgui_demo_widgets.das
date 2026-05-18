options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Integration smoke for the imgui_demo `widgets` scene. Boots the
//! single-scene harness driver and waits for WIDGETS_SECTION to register.

let IMGUI_DEMO_WIDGETS_HARNESS = "modules/dasImgui/examples/imgui_demo/harness_widgets.das"

[test]
def test_imgui_demo_widgets_smoke(t : T?) {
    with_imgui_app(IMGUI_DEMO_WIDGETS_HARNESS) $(d) {
        var snap0 = wait_for_widget(d, "WIDGETS_SECTION", 15.0f)
        t |> success(snap0 != null, "WIDGETS_SECTION registers (demo renders)")
        if (snap0 == null) return
        t |> equal(find_widget(snap0, "WIDGETS_SECTION")?["kind"] ?? "",
                   "collapsing_header",
                   "WIDGETS_SECTION.kind == 'collapsing_header'")
    }
}
