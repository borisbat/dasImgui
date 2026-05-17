options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _allow_imgui_legacy = true

module imgui_table_builtin shared

require imgui public
require imgui/imgui_boost_runtime public
require imgui/imgui_boost_v2 public
require imgui/imgui_containers_builtin public

//! Tables family — `[container] table` + six body-internal cursor wrappers.
//!
//! ImGui's table API splits into chrome that fires once per `BeginTable`
//! (the column-setup calls) and cursor primitives that step rows/columns
//! inside the body loop. All seven members live behind proper daslang
//! wrappers in this module (rather than ALLOWED_IMGUI extensions) so the
//! consumer surface stays uniform: `table { table_setup_column(...);
//! table_headers_row(); for (...) { table_next_row(); table_set_column_index(0); ... } }`.
//!
//! Sort-spec capture, multi-select hand-off, frozen-row indicators, and
//! custom row-bg callbacks belong to the future `tables.das` port and
//! extend `TableState` additively at that time.

[container]
def data_table(var state : TableState; text : string; columns : int;
               flags : ImGuiTableFlags; outer_size : float2; inner_width : float;
               blk : block) {
    //! `BeginTable(id, columns, flags, outer_size, inner_width)` / `EndTable()`
    //! — only-on-true pairing. Body emits `table_setup_column` /
    //! `table_setup_scroll_freeze` / `table_headers_row` / `table_next_row` /
    //! `table_set_column_index` / `table_next_column` cursor calls.
    state.columns = columns
    state.flags = flags
    state.outer_size = outer_size
    state.inner_width = inner_width
    let im_open = BeginTable(text, columns, flags, outer_size, inner_width)
    if (im_open) {
        invoke(blk)
        EndTable()
    }
    stateless_finalize(widget_ident, "data_table", state)
}

def public table_setup_column(text : string;
                              flags : ImGuiTableColumnFlags = ImGuiTableColumnFlags.None;
                              init_width_or_weight : float = 0.0f;
                              user_id : uint = 0u) {
    //! `TableSetupColumn(label, flags, init_width_or_weight, user_id)` — call
    //! once per column directly after BeginTable, before `table_headers_row`.
    TableSetupColumn(text, flags, init_width_or_weight, user_id)
}

def public table_setup_scroll_freeze(cols : int; rows : int) {
    //! `TableSetupScrollFreeze(cols, rows)` — pin the first ``cols`` columns
    //! and ``rows`` rows during ScrollX/ScrollY. Call before `table_headers_row`.
    TableSetupScrollFreeze(cols, rows)
}

def public table_headers_row() {
    //! `TableHeadersRow()` — submit the header row using the labels passed to
    //! the per-column `table_setup_column` calls.
    TableHeadersRow()
}

def public table_next_row(flags : ImGuiTableRowFlags = ImGuiTableRowFlags.None;
                          min_row_height : float = 0.0f) {
    //! `TableNextRow(flags, min_row_height)` — append a new row; pairs with
    //! per-column `table_set_column_index` or `table_next_column` calls.
    TableNextRow(flags, min_row_height)
}

def public table_next_column() : bool {
    //! `TableNextColumn()` — advance one column (or wrap to next row); returns
    //! true when the column is visible (caller may skip non-visible content).
    return TableNextColumn()
}

def public table_set_column_index(col : int) : bool {
    //! `TableSetColumnIndex(col)` — jump to ``col`` in the current row; returns
    //! true when the column is visible.
    return TableSetColumnIndex(col)
}
