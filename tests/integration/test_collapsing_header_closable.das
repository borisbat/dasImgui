options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _no_imgui_legacy = true

require dastest/testing_boost public
require imgui/imgui_lint
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Integration smoke for collapsing_header(closable=true) — verifies
//! the close-button route: imgui_close hides; imgui_open re-renders.

let FEATURE = "modules/dasImgui/examples/features/collapsing_header_closable.das"

[test]
def test_collapsing_header_closable_smoke(t : T?) {
    with_imgui_app(FEATURE) $(d) {
        var snap = wait_for_render(d, "MAIN_WIN/HEADER_CLOSE", 15.0f)
        t |> success(snap != null, "HEADER_CLOSE renders open")
        if (snap == null) return

        let open0 = widget_payload_field(snap, "MAIN_WIN/HEADER_CLOSE", "open") ?? false
        t |> equal(open0, true, "header starts open")

        close_widget(d, "MAIN_WIN/HEADER_CLOSE")
        let closed = wait_until(d, 300) $(var s) {
            return !widget_exists(s, "MAIN_WIN/HEADER_CLOSE/REVEAL_BTN")
        }
        t |> success(closed != null, "closing the header hides REVEAL_BTN inside")

        open_widget(d, "MAIN_WIN/HEADER_CLOSE")
        let reopened = wait_until(d, 300) $(var s) {
            return widget_exists(s, "MAIN_WIN/HEADER_CLOSE/REVEAL_BTN")
        }
        t |> success(reopened != null, "imgui_open re-renders body")
    }
}
