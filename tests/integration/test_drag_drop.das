options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Integration smoke for `drag_drop_source` + `drag_drop_target` containers.
//! Both register in the snapshot (stateless_finalize runs every frame).
//! Driving an actual drop is L1-fragile (depends on ImGui's drag threshold,
//! synth-mouse timing, and frame interleaving), so the L1 gate here just
//! checks `drag_to` returns ok — the visual demo proves the drop semantics.

let DRAG_DROP_FEATURE = "modules/dasImgui/examples/features/drag_drop.das"

[test]
def test_drag_drop_smoke(t : T?) {
    with_imgui_app(DRAG_DROP_FEATURE) $(d) {
        var snap0 = wait_for_widget(d, "MAIN_WIN/SOURCE_BTN", 15.0f)
        t |> success(snap0 != null, "SOURCE_BTN registers")
        if (snap0 == null) return

        let target_entry = find_widget(snap0, "MAIN_WIN/TARGET_BTN")
        t |> equal(target_entry?["kind"] ?? "", "button",
                   "TARGET_BTN.kind == 'button'")
        let src_dd = find_widget(snap0, "MAIN_WIN/SOURCE_DD")
        t |> equal(src_dd?["kind"] ?? "", "drag_drop_source",
                   "SOURCE_DD.kind == 'drag_drop_source'")
        let tgt_dd = find_widget(snap0, "MAIN_WIN/TARGET_DD")
        t |> equal(tgt_dd?["kind"] ?? "", "drag_drop_target",
                   "TARGET_DD.kind == 'drag_drop_target'")

        // Drive an L1 drag from SOURCE_BTN's bbox center to TARGET_BTN's
        // bbox center. Server replies ok with the source target name.
        let resp = drag_to(d, "MAIN_WIN/SOURCE_BTN", "MAIN_WIN/TARGET_BTN", 8, 0)
        t |> success(resp != null, "drag_to returned a response")
        t |> equal(resp?["ok"] ?? false, true,
                   "drag_to response.ok == true")
    }
}
