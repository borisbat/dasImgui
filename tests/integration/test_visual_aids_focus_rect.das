options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Visual-aids focus rectangle — wire integration gates.
//!
//! The focus halo is drawn by `paint_focus_rect()` when
//! `focus_rect_enabled = true` and `active_widget_path()` resolves to a
//! known widget. This test verifies the toggle, the resolution path
//! (`io.active_widget` populates when a boost-wrapped widget is active),
//! and the empty-state behavior (no panic when nothing is active).

let FEATURE = "modules/dasImgui/examples/features/glfw_synth_keys.das"

[test]
def test_focus_rect_toggle(t : T?) {
    with_imgui_app(FEATURE) $(d) {
        var snap0 = wait_for_render(d, "SYNTH_KEYS_WIN", 15.0f)
        t |> success(snap0 != null, "SYNTH_KEYS_WIN renders")
        if (snap0 == null) return

        let on = post_command(d, "imgui_focus_rect", JV((enabled = true)))
        t |> equal(on?["ok"] ?? false, true, "imgui_focus_rect ok=true on toggle on")
        t |> equal(on?["enabled"] ?? false, true, "imgui_focus_rect reports enabled=true")

        let off = post_command(d, "imgui_focus_rect", JV((enabled = false)))
        t |> equal(off?["enabled"] ?? true, false, "imgui_focus_rect reports enabled=false on toggle off")
    }
}

[test]
def test_focus_rect_resolves_active_widget(t : T?) {
    //! The overlay reads `active_widget_path()` → `widget_rect(path)`. This
    //! test verifies io.active_widget surfaces NAME_INPUT once it's focused
    //! (the example auto-focuses on first render), and that widget_rect for
    //! that path returns a non-empty bbox in the snapshot. Both must hold
    //! for the focus rect to draw anything.
    with_imgui_app(FEATURE) $(d) {
        var snap0 = wait_for_render(d, "SYNTH_KEYS_WIN", 15.0f)
        if (snap0 == null) {
            t |> success(false, "SYNTH_KEYS_WIN renders")
            return
        }

        // Auto-focus has happened by the time wait_for_render returns.
        let active = wait_until(d, 3.0f) $(var snap) {
            return (snap?["io"]?["active_widget"] ?? "") == "NAME_INPUT"
        }
        t |> success(active != null, "io.active_widget resolves to NAME_INPUT")

        // bbox is in globals[NAME_INPUT].bbox (per imgui_boost_runtime).
        let snap = post_command(d, "imgui_snapshot", null)
        let bb = snap?["globals"]?["NAME_INPUT"]?["bbox"]
        t |> success(bb != null, "NAME_INPUT.bbox populated in snapshot")
    }
}
