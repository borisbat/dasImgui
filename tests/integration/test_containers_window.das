options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require live_driver public
require daslib/json public
require daslib/json_boost public

//! Integration smoke for Phase 0b.3 window/child/group containers. Verifies
//! hierarchical registry keys (leaf widgets nested inside a `[container]`
//! show up under "MAIN_WIN/<ident>" rather than bare ident), and that
//! imgui_set / imgui_click / imgui_open all resolve against the path-keyed
//! dispatcher table.

let WINDOW_FEATURE = "modules/dasImgui/examples/features/containers_window.das"

[test]
def test_containers_window_smoke(t : T?) {
    with_live_app(WINDOW_FEATURE) $(d) {
        // The first leaf inside MAIN_WIN registers under the hierarchical
        // path "MAIN_WIN/SAVE" — that's the gate the harness should wait on.
        var snap0 = wait_for_widget(d, "MAIN_WIN/SAVE", 15.0f)
        t |> success(snap0 != null, "MAIN_WIN/SAVE registered after first frame")
        if (snap0 == null) {
            return
        }

        // ----- Container itself appears in registry under path key -----
        var main_entry = find_widget(snap0, "MAIN_WIN")
        t |> equal(from_JV(main_entry?["kind"], type<string>, ""), "window",
                   "MAIN_WIN registers as kind=window")

        // ----- Leaves nested inside the container use hierarchical keys -----
        var save_entry = find_widget(snap0, "MAIN_WIN/SAVE")
        t |> equal(from_JV(save_entry?["kind"], type<string>, ""), "button",
                   "MAIN_WIN/SAVE registers as kind=button (leaf under container)")

        // Bare "SAVE" must NOT exist as a top-level key — the only entry is
        // the path-prefixed one.
        t |> success(!widget_exists(snap0, "SAVE"),
                     "bare SAVE not registered (path-keyed only)")

        // ----- Click via the path-keyed dispatcher -----
        click(d, "MAIN_WIN/SAVE")
        t |> success(wait_for_int_value(d, "MAIN_WIN/SAVE", "click_count", 1, 5.0f),
                     "imgui_click MAIN_WIN/SAVE bumps click_count")

        // ----- imgui_set on a nested slider -----
        set_value(d, "MAIN_WIN/SPEED", JV(7.5f))
        t |> success(wait_for_payload_value(d, "MAIN_WIN/SPEED", "value", 7.5f, 5.0f),
                     "imgui_set steers MAIN_WIN/SPEED to 7.5")

        // ----- Three-deep nesting: window > child > leaf -----
        var snap1 = snapshot(d)
        var wire_entry = find_widget(snap1, "MAIN_WIN/LEFT_PANEL/WIRE")
        t |> equal(from_JV(wire_entry?["kind"], type<string>, ""), "checkbox",
                   "MAIN_WIN/LEFT_PANEL/WIRE registers under 3-deep path")
        set_value(d, "MAIN_WIN/LEFT_PANEL/WIRE", JV(true))
        t |> success(wait_for_bool_value(d, "MAIN_WIN/LEFT_PANEL/WIRE", "value", true, 5.0f),
                     "imgui_set MAIN_WIN/LEFT_PANEL/WIRE flips it true")

        // ----- group(RIGHT_GROUP) inside MAIN_WIN, then leaf inside it -----
        var power_entry = find_widget(snap1, "MAIN_WIN/RIGHT_GROUP/POWER")
        t |> equal(from_JV(power_entry?["kind"], type<string>, ""), "slider_int",
                   "MAIN_WIN/RIGHT_GROUP/POWER registers under nested group path")
        set_value(d, "MAIN_WIN/RIGHT_GROUP/POWER", JV(42))
        t |> success(wait_for_int_value(d, "MAIN_WIN/RIGHT_GROUP/POWER", "value", 42, 5.0f),
                     "imgui_set on a leaf nested in window>group works")

        // ----- imgui_open on a closable window flips state.open -----
        // DETAIL_WIN starts closed (state.open zero-init). Open it, expect
        // its first leaf (PING) to appear in subsequent snapshots.
        open_widget(d, "DETAIL_WIN")
        var snap_open = wait_until(d, 5.0f) $(var snap) {
            return widget_exists(snap, "DETAIL_WIN/PING")
        }
        t |> success(snap_open != null,
                     "imgui_open DETAIL_WIN flips state.open and renders nested leaves")

        // ----- imgui_close hides the window again -----
        close_widget(d, "DETAIL_WIN")
        var snap_closed = wait_until(d, 5.0f) $(var snap) {
            return !widget_exists(snap, "DETAIL_WIN/PING")
        }
        t |> success(snap_closed != null,
                     "imgui_close DETAIL_WIN hides nested leaves on next frame")
    }
}
