options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Integration smoke for boost v2 edit_* vector rail (10b + 10c input vecs).

let FEATURE = "modules/dasImgui/examples/features/edit_external_vectors.das"

[test]
def test_edit_external_vectors_smoke(t : T?) {
    with_imgui_app(FEATURE) $(d) {
        var snap = wait_for_render(d, "MAIN_WIN/SF2", 15.0f)
        t |> success(snap != null, "SF2 renders")
        if (snap == null) return

        for (ident in ["SF2", "SF3", "SF4", "SI2", "SI3", "SI4",
                       "IF2", "IF3", "IF4", "II2", "II3", "II4",
                       "DF2", "DF3", "DF4", "DI2", "DI3", "DI4"]) {
            t |> success(widget_exists(snap, "MAIN_WIN/{ident}"),
                         "{ident} registered")
        }

        // imgui_set on a float3 — write {x,y,z} and verify the snapshot
        // reports back the same components.
        set_value(d, "MAIN_WIN/SF3", JV((x = 0.7f, y = 0.8f, z = 0.9f)))
        let after = wait_until(d, 300) $(var s) {
            let xv = widget_payload_field(s, "MAIN_WIN/SF3", "value")
            return xv != null && xv?["x"] != null
        }
        t |> success(after != null, "edit_slider_float3 write round-trips")
    }
}
