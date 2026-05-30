options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Contract test for the snapshot item-transform hook (set/clear_snapshot_item_transform).
//! Drives examples/features/snapshot_transform.das, which wraps ONE button in a known
//! synthetic affine (scale (2,3), offset (100,50)) with plain buttons before it and
//! after the clear. Asserts:
//!   - the transformed button reports bbox = canvas_bbox*scale + offset (the captured
//!     local rect mapped to screen), with canvas_bbox carrying the local rect;
//!   - widgets with no active transform (before, and after clear) report a screen-native
//!     bbox and NO canvas_bbox — i.e. clear restores the default behavior.

let FEATURE = "modules/dasImgui/examples/features/snapshot_transform.das"

def private near(a : float; b : float; tol : float) : bool {
    let d = a - b
    return d <= tol && d >= -tol
}

[test]
def test_snapshot_transform(t : T?) {
    with_imgui_app(FEATURE) $(d) {
        var snap = wait_for_widget(d, "MAIN_WIN/XFORM_BTN", 15.0f)
        t |> success(snap != null, "snapshot returned with the transformed button registered")
        if (snap == null) return

        // ---- no active transform before: screen-native, no canvas_bbox ----
        t |> success(widget_exists(snap, "MAIN_WIN/PLAIN_BTN"), "plain button present")
        let plain_cbb = find_widget(snap, "MAIN_WIN/PLAIN_BTN")?["canvas_bbox"]?["z"] ?? -1.0f
        t |> success(plain_cbb < 0.0f, "plain button carries no canvas_bbox (no active transform)")

        // ---- under the transform: bbox = local*scale + offset, canvas_bbox = local ----
        let xf = find_widget(snap, "MAIN_WIN/XFORM_BTN")
        let lx = xf?["canvas_bbox"]?["x"] ?? -1.0f
        let ly = xf?["canvas_bbox"]?["y"] ?? -1.0f
        let lz = xf?["canvas_bbox"]?["z"] ?? -1.0f
        let lw = xf?["canvas_bbox"]?["w"] ?? -1.0f
        t |> success(lx >= 0.0f && lz > lx, "xform button carries a canvas_bbox (local rect)")
        let bx = xf?["bbox"]?["x"] ?? 0.0f
        let by = xf?["bbox"]?["y"] ?? 0.0f
        let bz = xf?["bbox"]?["z"] ?? 0.0f
        let bw = xf?["bbox"]?["w"] ?? 0.0f
        t |> success(near(bx, lx * 2.0f + 100.0f, 0.5f), "bbox.x == local.x*2 + 100")
        t |> success(near(by, ly * 3.0f + 50.0f, 0.5f), "bbox.y == local.y*3 + 50")
        t |> success(near(bz, lz * 2.0f + 100.0f, 0.5f), "bbox.z == local.z*2 + 100")
        t |> success(near(bw, lw * 3.0f + 50.0f, 0.5f), "bbox.w == local.w*3 + 50")

        // ---- after clear: screen-native again, no canvas_bbox ----
        t |> success(widget_exists(snap, "MAIN_WIN/AFTER_BTN"), "after-clear button present")
        let after_cbb = find_widget(snap, "MAIN_WIN/AFTER_BTN")?["canvas_bbox"]?["z"] ?? -1.0f
        t |> success(after_cbb < 0.0f, "after-clear button carries no canvas_bbox (clear restored identity)")
    }
}
