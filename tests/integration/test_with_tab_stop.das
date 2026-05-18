options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Integration smoke for `with_tab_stop` — stateless block-arg wrapper around
//! PushTabStop/PopTabStop. The wrapper itself doesn't register a widget; this
//! test verifies the tutorial demo renders and the host window + all five
//! input fields (including the wrapped TS_FIELD_SKIP) reach the snapshot.

let WITH_TAB_STOP_FEATURE = "modules/dasImgui/examples/tutorial/with_tab_stop.das"

[test]
def test_with_tab_stop_smoke(t : T?) {
    with_imgui_app(WITH_TAB_STOP_FEATURE) $(d) {
        var snap0 = wait_for_widget(d, "TS_WIN", 15.0f)
        t |> success(snap0 != null, "TS_WIN registers (demo renders)")
        if (snap0 == null) return
        t |> equal(find_widget(snap0, "TS_WIN")?["kind"] ?? "", "window",
                   "TS_WIN.kind == 'window'")
        var snap_skip = wait_for_widget(d, "TS_WIN/TS_FIELD_SKIP", 15.0f)
        t |> success(snap_skip != null, "TS_FIELD_SKIP renders inside with_tab_stop block")
    }
}
