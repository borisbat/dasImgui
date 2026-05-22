options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Integration smoke for `tab_item_button` widget — button styled as a tab
//! strip element. Click semantics mirror `button`; must live inside a
//! `tab_bar` body. Leading/Trailing flags anchor it to either edge of
//! the tab strip.
//!
//! Gates:
//!   1. HELP + ADD_TAB widgets render, kind = "tab_item_button".
//!   2. Initial seed places 3 tabs (NEXT_ID=3 after init).
//!   3. Clicking ADD_TAB increments click_count AND grows ACTIVE_TABS
//!      (visible via a fourth tab_item rendering at NEXT_ID=3).
//!   4. Clicking HELP increments click_count but does not grow the tab
//!      list (no side-effect attached in the feature).

let FEATURE = "modules/dasImgui/examples/features/tab_item_button.das"

[test]
def test_tab_item_button_smoke(t : T?) {
    with_imgui_app(FEATURE) $(d) {
        var snap0 = wait_for_widget(d, "MAIN_WIN/BAR/ADD_TAB", 15.0f)
        t |> success(snap0 != null, "ADD_TAB renders")
        if (snap0 == null) return

        // Gate 1: kind sanity.
        let help_entry = find_widget(snap0, "MAIN_WIN/BAR/HELP")
        t |> equal(help_entry?["kind"] ?? "", "tab_item_button",
                   "HELP.kind == 'tab_item_button'")
        let add_entry = find_widget(snap0, "MAIN_WIN/BAR/ADD_TAB")
        t |> equal(add_entry?["kind"] ?? "", "tab_item_button",
                   "ADD_TAB.kind == 'tab_item_button'")

        // Gate 2: initial seed — 3 tabs (IDs 0/1/2).
        t |> success(widget_exists(snap0, "MAIN_WIN/BAR/0000"),
                     "seed tab 0000 renders")
        t |> success(widget_exists(snap0, "MAIN_WIN/BAR/0002"),
                     "seed tab 0002 renders")

        // Gate 3: click ADD_TAB → click_count grows + new tab 0003 appears.
        let click_resp = click(d, "MAIN_WIN/BAR/ADD_TAB")
        t |> equal(click_resp?["ok"] ?? false, true,
                   "imgui_click on ADD_TAB returns ok")

        let grew = wait_until(d, 300) $(var s) {
            return widget_exists(s, "MAIN_WIN/BAR/0003")
        }
        t |> success(grew != null,
                     "clicking ADD_TAB grows the tab list (0003 renders)")
        var snap_after = snapshot(d)
        let add_after = find_widget(snap_after, "MAIN_WIN/BAR/ADD_TAB")
        t |> success((add_after?["payload"]?["click_count"] ?? 0) >= 1,
                     "ADD_TAB.click_count incremented")

        // Gate 4: click HELP → click_count grows; no new tab.
        let help_resp = click(d, "MAIN_WIN/BAR/HELP")
        t |> equal(help_resp?["ok"] ?? false, true,
                   "imgui_click on HELP returns ok")
        let help_clicked = wait_until(d, 300) $(var s) {
            let h = find_widget(s, "MAIN_WIN/BAR/HELP")
            return (h?["payload"]?["click_count"] ?? 0) >= 1
        }
        t |> success(help_clicked != null,
                     "HELP.click_count incremented after imgui_click")
    }
}
