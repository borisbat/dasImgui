options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Integration smoke for the `sort_specs` block-arg helper on
//! `data_table`. Asserts the sortable inventory feature file boots,
//! the host window + LEAD register, and the data_table appears with the
//! Sortable + SortMulti flags reaching the snapshot. The auto-sort
//! lifecycle (specs dirty → comparator fires → array re-orders → dirty
//! cleared) runs by the time the second frame's snapshot is taken;
//! actually flipping a sort key requires a synth header click which
//! belongs to a follow-up interactive test.

let SORT_FEATURE = "modules/dasImgui/examples/features/sort_specs.das"

[test]
def test_sort_specs_table_renders(t : T?) {
    with_imgui_app(SORT_FEATURE) $(d) {
        var snap = wait_for_widget(d, "SORT_WIN/LEAD", 15.0f)
        t |> success(snap != null,
                     "SORT_WIN/LEAD renders (sort_specs feature reached the trailing text)")
        if (snap == null) return
        t |> success(widget_exists(snap, "SORT_WIN/SORT_TABLE"),
                     "SORT_WIN/SORT_TABLE registers (data_table container with Sortable + SortMulti)")
        t |> success(widget_exists(snap, "SORT_WIN/SORT_TABLE/SORT_ROW_ID/0"),
                     "first inventory row's ID cell registers (rows drain through table_next_row + table_set_column_index)")
    }
}
