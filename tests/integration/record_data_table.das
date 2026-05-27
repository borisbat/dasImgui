options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``data_table.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_data_table.das
//!
//! Demonstrates Sortable table by CLICKING column headers (Name then
//! Type) — viewer sees the row order shuffle each click as
//! ``sort_specs() $(specs) { sort_rows(specs) }`` fires. Headers don't
//! have boost-registered idents (TableHeadersRow is ImGui-internal), so
//! the click position is computed by offset from each column's row-0 cell.

def widget_bbox(var snap : JsonValue?; ident : string) : float4 {
    var b = snap?["globals"]?[ident]?["bbox"]
    return float4(
        b?["x"] ?? 0.0f,
        b?["y"] ?? 0.0f,
        b?["z"] ?? 0.0f,
        b?["w"] ?? 0.0f
    )
}

def widget_center(var snap : JsonValue?; ident : string) : tuple<float; float> {
    let b = widget_bbox(snap, ident)
    return ((b.x + b.z) * 0.5f, (b.y + b.w) * 0.5f)
}

[export]
def main {
    with_recording_app("examples/tutorial/data_table.das",
                       "data_table.apng", 60) $(app) {
        // Window-prefixed registry paths for the cells we'll narrate.
        let T_TABLE = "DT_WIN/DT_TABLE"
        let T_NAME0 = "DT_WIN/DT_TABLE/DT_NAME[0]"
        let T_KIND0 = "DT_WIN/DT_TABLE/DT_KIND[0]"
        let T_VAL0  = "DT_WIN/DT_TABLE/DT_VAL[0]"
        let T_VAL5  = "DT_WIN/DT_TABLE/DT_VAL[5]"

        var snap = wait_for_widget(app, T_NAME0, 10.0f)
        if (snap == null) {
            panic("{T_NAME0} never rendered — wrong app running?")
        }
        let p_table = widget_center(snap, T_TABLE)
        let p_name0 = widget_center(snap, T_NAME0)
        let p_kind0 = widget_center(snap, T_KIND0)
        let p_val0  = widget_center(snap, T_VAL0)
        let p_val5  = widget_center(snap, T_VAL5)

        // Header row sits directly above row 0 by ~22 ImGui-default px.
        let header_dy = 22.0f
        let p_name_hdr = (p_name0._0, p_name0._1 - header_dy)
        let p_kind_hdr = (p_kind0._0, p_kind0._1 - header_dy)

        // ---- Stage 1: announce the container ----
        move_to(app, p_table)
        sleep(SETTLE_MS)
        say(app, "data_table — boost container around ImGui BeginTable/EndTable. Flags here: Sortable | SortMulti | Resizable | Reorderable | Hideable | RowBg.", T_TABLE)

        // ---- Stage 2: per-column cell visit shows the column structure ----
        move_to(app, p_name0)
        sleep(SETTLE_MS)
        say(app, "table_set_column_index(0) puts the cursor in the Name column. Per-row IDs (DT_NAME[i]) make each cell individually addressable.", T_NAME0)

        move_to(app, p_val5)
        sleep(SETTLE_MS)
        say(app, "Six rows × three columns; the last cell (DT_VAL[5]=0.001) anchors the Value column. Sort order is currently the seed order.", T_VAL5)

        // ---- Stage 3: click Name header — fires sort_specs() $(specs) callback ----
        var name_sort_events : array<JsonValue?>
        name_sort_events |> click_at(0, p_name_hdr, 700)
        post_command(app, "imgui_mouse_play", JV((events = name_sort_events)))
        sleep(CLICK_DWELL_MS)
        say(app, "Click the Name header — sort_specs() fires, sort_rows() runs the comparator, ROWS is sorted by name ascending. Click again to flip to descending.", T_NAME0)

        // ---- Stage 4: click Type header — re-sort by Type, watch rows shuffle ----
        var kind_sort_events : array<JsonValue?>
        kind_sort_events |> click_at(0, p_kind_hdr, 700)
        post_command(app, "imgui_mouse_play", JV((events = kind_sort_events)))
        sleep(CLICK_DWELL_MS)
        say(app, "Click the Type header — sort_specs reports the new column_user_id, comparator routes on it, rows re-sort by type. column_user_id (not column_index) makes the sort survive column reorder.", T_KIND0)

        // ---- Stage 5: callout the SortMulti / Reorderable / Hideable features ----
        move_to(app, p_table)
        sleep(SETTLE_MS)
        say(app, "Try live: Shift+click a second header for SortMulti (secondary sort key). Drag a header to reorder. Right-click for the Hideable column toggle.", T_TABLE)
    }
}
