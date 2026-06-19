options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Integration smoke for the wrapping tab bar. Opens the wrap_tab_bar tutorial,
//! asserts tab 0 is active by default (its body renders, an inactive body does
//! not), then force-selects tab 2 by index and asserts the active body follows.
//! Proves the widget is both snapshot-visible (the `value` payload) and
//! programmatically drivable — the upgrade over ImGui's native TabBar.

let WRAP_FEATURE = "modules/dasImgui/examples/tutorial/wrap_tab_bar.das"

[test]
def test_wrap_tab_bar(t : T?) {
    with_imgui_app(WRAP_FEATURE) $(d) {
        var snap = wait_for_widget(d, "WTB_WIN/WTB_BAR", 15.0f)
        t |> success(snap != null, "wrap_tab_bar renders")
        if (snap == null) {
            return
        }

        // default: first tab active, its body shown, an inactive body hidden
        t |> success((widget_payload_field(snap, "WTB_WIN/WTB_BAR", "value") ?? -1) == 0,
                     "tab 0 active by default")
        t |> success(widget_rendered(snap, "WTB_WIN/WTB_BAR/WTB_B0"), "tab 0 body renders")
        t |> success(!widget_rendered(snap, "WTB_WIN/WTB_BAR/WTB_B2"), "inactive tab 2 body hidden")

        // drive: select tab 2 (lava) by index — exercises has_pending/pending_value
        force_set_value(d, "WTB_WIN/WTB_BAR", JV(2))
        var snap2 = wait_until_sec(d, 5.0f) $(var s) {
            return (widget_payload_field(s, "WTB_WIN/WTB_BAR", "value") ?? -1) == 2
        }
        t |> success(snap2 != null, "force_set selects tab 2")
        if (snap2 == null) {
            return
        }
        t |> success(widget_rendered(snap2, "WTB_WIN/WTB_BAR/WTB_B2"), "tab 2 body renders after switch")
        t |> success(!widget_rendered(snap2, "WTB_WIN/WTB_BAR/WTB_B0"), "tab 0 body hidden after switch")
    }
}
