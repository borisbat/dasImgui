options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public
require strings

//! Scope-wrapper semantics for the drawlist rail. Targets
//! ``examples/features/drawlist.das``. Verifies:
//!   - ``with_window_drawlist`` paints inside ``DRAW_WIN`` — every primitive's
//!     path key is nested under ``DRAW_WIN/``.
//!   - ``with_foreground_drawlist`` paints OUTSIDE the window — at least one
//!     primitive (``add_rect_filled`` from the FG ribbon) registers WITHOUT
//!     the ``DRAW_WIN/`` prefix.

let DRAWLIST_FEATURE = "modules/dasImgui/examples/features/drawlist.das"

def count_primitives_under(var snap : JsonValue?; prefix : string) : int {
    var n = 0
    var globals = snap?["globals"]
    return n if (globals == null || !(globals.value is _object))
    for (k, v in keys(globals.value as _object), values(globals.value as _object)) {
        let kind = string(v?["kind"] ?? "")
        if (length(kind) > 4 && slice(kind, 0, 4) == "add_") {
            if (length(prefix) == 0) {
                n++ if (find(k, "/") == -1)
            } else {
                n++ if (length(k) > length(prefix) && slice(k, 0, length(prefix)) == prefix)
            }
        }
    }
    return n
}

[test]
def test_with_window_drawlist_nests(t : T?) {
    with_imgui_app(DRAWLIST_FEATURE) $(d) {
        var snap = wait_for_widget(d, "DRAW_WIN/DRAW_BAND_SLOT", 15.0f)
        t |> success(snap != null, "feature renders")
        if (snap == null) return
        // Window drawlist primitives nest under DRAW_WIN/.
        let nested = count_primitives_under(snap, "DRAW_WIN/")
        t |> success(nested >= 5,
                     "with_window_drawlist primitives nest under DRAW_WIN/ (got {nested})")
        // Foreground / background drawlist primitives are NOT inside DRAW_WIN —
        // they paint to viewport-level drawlists with no container path.
        let unnested = count_primitives_under(snap, "")
        t |> success(unnested >= 1,
                     "with_foreground_drawlist / with_background_drawlist primitives are unnested (got {unnested})")
    }
}
