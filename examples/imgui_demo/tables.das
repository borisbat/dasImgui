options gen2
options indenting = 4

module tables

require imgui
require imgui/imgui_widgets_builtin
require imgui/imgui_containers_builtin
require imgui/imgui_layout_builtin
require imgui/imgui_id_builtin
require imgui/imgui_scope_builtin
require imgui/imgui_style_builtin
require imgui/imgui_table_builtin
require daslib/safe_addr

// =============================================================================
// Mirrors imgui_demo.cpp:4154-6044 — static void ShowDemoWindowTables().
//
// Port status (PR-D, this commit): section 1 Basic + section 2 Borders,
// background. Remaining 22 sections (Resizable family / Padding / Sizing
// policies / Scrolling / Columns flags / Background color / Tree view /
// Custom headers / Angled headers / Context menus / Synced instances /
// Sorting / Advanced) land in follow-up commits.
//
// Boost-surface conventions:
// - cpp `static` locals → module-scope `var private` (state-hoist).
// - cpp `PushID("Tables")` outer scope dropped — each `data_table(IDENT,
//   ...)` already auto-PushID's its unique IDENT, so cross-section
//   collisions can't happen.
// - cpp Expand all / Collapse all driver → `g_open_action` gate with
//   `apply_open_action()` called before each `tree_node(...)`. Reset to
//   -1 at the end of the dispatcher.
// - cpp `HelpMarker(text)` bubbles → dropped per the app_dockspace
//   precedent (extra widget IDENTs + tooltip plumbing for context that's
//   either obvious from the section title or redundant with our own
//   docstring). May be reintroduced as a local helper if later sections
//   carry load-bearing help text.
// - Per-section helpers: one `def private show_section_<n>()` per
//   CollapsingHeader sub-section so the dispatcher reads as a 24-line
//   sequence.
// =============================================================================

// Shared Expand all / Collapse all driver.
var private g_open_action : int = -1

def private apply_open_action() {
    if (g_open_action != -1) {
        SetNextItemOpen(g_open_action != 0, ImGuiCond.Always)
    }
}

// ---- Section 1 Basic state ----
// All three table methods iterate procedurally; per-cell text needs its own
// NarrativeState per call site. Indexed table state keeps each cell distinct
// in the widget registry.
var private TABLES_BASIC_T1_CELL : table<int; NarrativeState>
var private TABLES_BASIC_T2_CELL : table<int; NarrativeState>
var private TABLES_BASIC_T3_CELL : table<int; NarrativeState>

// ---- Section 2 Borders, background state ----
var private TABLES_BORDERS_FLAGS    : int  = int(ImGuiTableFlags.Borders |
                                                 ImGuiTableFlags.RowBg)
var private TABLES_BORDERS_CONTENTS : RadioIntState
var private TABLES_BORDERS_T1_CELL_TEXT : table<int; NarrativeState>
var private TABLES_BORDERS_T1_CELL_BTN  : table<int; ClickState>

// ---- Section 3 Resizable, stretch state ----
var private TABLES_RSTRETCH_FLAGS : int = int(ImGuiTableFlags.SizingStretchSame |
                                              ImGuiTableFlags.Resizable |
                                              ImGuiTableFlags.BordersOuter |
                                              ImGuiTableFlags.BordersV |
                                              ImGuiTableFlags.ContextMenuInBody)
var private TABLES_RSTRETCH_CELL : table<int; NarrativeState>

// ---- Section 4 Resizable, fixed state ----
var private TABLES_RFIXED_FLAGS : int = int(ImGuiTableFlags.SizingFixedFit |
                                            ImGuiTableFlags.Resizable |
                                            ImGuiTableFlags.BordersOuter |
                                            ImGuiTableFlags.BordersV |
                                            ImGuiTableFlags.ContextMenuInBody)
var private TABLES_RFIXED_CELL : table<int; NarrativeState>

// ---- Section 5 Resizable, mixed state ----
// Same flag set drives both sub-tables (3-col and 6-col). Per-column
// WidthFixed/WidthStretch + DefaultHide configured at TableSetupColumn time.
var private TABLES_RMIXED_FLAGS : int = int(ImGuiTableFlags.SizingFixedFit |
                                            ImGuiTableFlags.RowBg |
                                            ImGuiTableFlags.Borders |
                                            ImGuiTableFlags.Resizable |
                                            ImGuiTableFlags.Reorderable |
                                            ImGuiTableFlags.Hideable)
var private TABLES_RMIXED_T1_CELL : table<int; NarrativeState>
var private TABLES_RMIXED_T2_CELL : table<int; NarrativeState>

// ---- Section 6 Reorderable, hideable, with headers state ----
var private TABLES_RHH_FLAGS : int = int(ImGuiTableFlags.Resizable |
                                         ImGuiTableFlags.Reorderable |
                                         ImGuiTableFlags.Hideable |
                                         ImGuiTableFlags.BordersOuter |
                                         ImGuiTableFlags.BordersV)
var private TABLES_RHH_T1_CELL : table<int; NarrativeState>
var private TABLES_RHH_T2_CELL : table<int; NarrativeState>

def ShowDemoWindowTables() {
    collapsing_header(TABLES_SECTION,
                      (text = "Tables & Columns", closable = false,
                       flags = ImGuiTreeNodeFlags.None)) {
        // Expand all / Collapse all toolbar.
        if (button(TABLES_EXPAND_ALL_BTN, (text = "Expand all"))) {
            g_open_action = 1
        }
        same_line(TABLES_SL_EXPAND)
        if (button(TABLES_COLLAPSE_ALL_BTN, (text = "Collapse all"))) {
            g_open_action = 0
        }
        separator(TABLES_SEP_TOOLBAR)

        show_basic()
        show_borders_background()
        show_resizable_stretch()
        show_resizable_fixed()
        show_resizable_mixed()
        show_reorderable_hideable_headers()

        // Reset open_action so the next frame's tree_nodes inherit their
        // sticky open/closed state instead of being forced again.
        g_open_action = -1
    }
}

// =============================================================================
// Section 1: Basic — cpp:4198-4256
// =============================================================================
def private show_basic() {
    apply_open_action()
    tree_node(TABLES_BASIC, (text = "Basic", flags = ImGuiTreeNodeFlags.None)) {
        // Method 1: TableNextRow + TableSetColumnIndex per cell.
        data_table(TABLES_BASIC_T1, (text = "##t1", columns = 3,
                                     flags = ImGuiTableFlags.None,
                                     outer_size = float2(0.0f, 0.0f),
                                     inner_width = 0.0f)) {
            for (row in range(4)) {
                table_next_row()
                for (col in range(3)) {
                    table_set_column_index(col)
                    let key = row * 3 + col
                    text(TABLES_BASIC_T1_CELL[key],
                         (text = "Row {row} Column {col}"))
                }
            }
        }

        // Method 2: TableNextRow + TableNextColumn manually per cell.
        data_table(TABLES_BASIC_T2, (text = "##t2", columns = 3,
                                     flags = ImGuiTableFlags.None,
                                     outer_size = float2(0.0f, 0.0f),
                                     inner_width = 0.0f)) {
            for (row in range(4)) {
                table_next_row()
                table_next_column()
                text(TABLES_BASIC_T2_CELL[row * 3 + 0], (text = "Row {row}"))
                table_next_column()
                text(TABLES_BASIC_T2_CELL[row * 3 + 1], (text = "Some contents"))
                table_next_column()
                text(TABLES_BASIC_T2_CELL[row * 3 + 2], (text = "123.456"))
            }
        }

        // Method 3: TableNextColumn auto-wraps to new rows.
        data_table(TABLES_BASIC_T3, (text = "##t3", columns = 3,
                                     flags = ImGuiTableFlags.None,
                                     outer_size = float2(0.0f, 0.0f),
                                     inner_width = 0.0f)) {
            for (item in range(14)) {
                table_next_column()
                text(TABLES_BASIC_T3_CELL[item], (text = "Item {item}"))
            }
        }
    }
}

// =============================================================================
// Section 2: Borders, background — cpp:4261-4327
// =============================================================================
def private show_borders_background() {
    apply_open_action()
    tree_node(TABLES_BORDERS, (text = "Borders, background",
                               flags = ImGuiTreeNodeFlags.None)) {
        // Borders/background flag toggles. The nested with_indent blocks
        // mirror the cpp Indent/Unindent visual grouping (BordersH /
        // BordersV split into Outer + Inner sub-toggles).
        edit_checkbox_flags(safe_addr(TABLES_BORDERS_FLAGS),
            (id = "TBL_B_F_ROWBG", text = "ImGuiTableFlags_RowBg",
             flags_value = int(ImGuiTableFlags.RowBg)))
        edit_checkbox_flags(safe_addr(TABLES_BORDERS_FLAGS),
            (id = "TBL_B_F_BORDERS", text = "ImGuiTableFlags_Borders",
             flags_value = int(ImGuiTableFlags.Borders)))
        with_indent(0.0f) {
            edit_checkbox_flags(safe_addr(TABLES_BORDERS_FLAGS),
                (id = "TBL_B_F_BORDERSH", text = "ImGuiTableFlags_BordersH",
                 flags_value = int(ImGuiTableFlags.BordersH)))
            with_indent(0.0f) {
                edit_checkbox_flags(safe_addr(TABLES_BORDERS_FLAGS),
                    (id = "TBL_B_F_BORDERSOH", text = "ImGuiTableFlags_BordersOuterH",
                     flags_value = int(ImGuiTableFlags.BordersOuterH)))
                edit_checkbox_flags(safe_addr(TABLES_BORDERS_FLAGS),
                    (id = "TBL_B_F_BORDERSIH", text = "ImGuiTableFlags_BordersInnerH",
                     flags_value = int(ImGuiTableFlags.BordersInnerH)))
            }
            edit_checkbox_flags(safe_addr(TABLES_BORDERS_FLAGS),
                (id = "TBL_B_F_BORDERSV", text = "ImGuiTableFlags_BordersV",
                 flags_value = int(ImGuiTableFlags.BordersV)))
            with_indent(0.0f) {
                edit_checkbox_flags(safe_addr(TABLES_BORDERS_FLAGS),
                    (id = "TBL_B_F_BORDERSOV", text = "ImGuiTableFlags_BordersOuterV",
                     flags_value = int(ImGuiTableFlags.BordersOuterV)))
                edit_checkbox_flags(safe_addr(TABLES_BORDERS_FLAGS),
                    (id = "TBL_B_F_BORDERSIV", text = "ImGuiTableFlags_BordersInnerV",
                     flags_value = int(ImGuiTableFlags.BordersInnerV)))
            }
            edit_checkbox_flags(safe_addr(TABLES_BORDERS_FLAGS),
                (id = "TBL_B_F_BORDERSO", text = "ImGuiTableFlags_BordersOuter",
                 flags_value = int(ImGuiTableFlags.BordersOuter)))
            edit_checkbox_flags(safe_addr(TABLES_BORDERS_FLAGS),
                (id = "TBL_B_F_BORDERSI", text = "ImGuiTableFlags_BordersInner",
                 flags_value = int(ImGuiTableFlags.BordersInner)))
        }

        // Contents-type radio (Text vs FillButton) + display-headers checkbox.
        align_text_to_frame_padding(TABLES_BORDERS_ATFP)
        text(TABLES_BORDERS_CT_LABEL, (text = "Cell contents:"))
        same_line(TABLES_BORDERS_SL_RT)
        radio_button_int(TABLES_BORDERS_CONTENTS, (text = "Text", v_button = 0))
        same_line(TABLES_BORDERS_SL_RFB)
        radio_button_int(TABLES_BORDERS_CONTENTS, (text = "FillButton", v_button = 1))

        checkbox(TABLES_BORDERS_DH_CHECK, (text = "Display headers", init = false))

        edit_checkbox_flags(safe_addr(TABLES_BORDERS_FLAGS),
            (id = "TBL_B_F_NBINBODY", text = "ImGuiTableFlags_NoBordersInBody",
             flags_value = int(ImGuiTableFlags.NoBordersInBody)))

        // 3x5 grid driven by the runtime flag set + contents-type selection.
        data_table(TABLES_BORDERS_T1, (text = "##bt1", columns = 3,
                                       flags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_BORDERS_FLAGS)),
                                       outer_size = float2(0.0f, 0.0f),
                                       inner_width = 0.0f)) {
            if (TABLES_BORDERS_DH_CHECK.value) {
                table_setup_column("One")
                table_setup_column("Two")
                table_setup_column("Three")
                table_headers_row()
            }
            for (row in range(5)) {
                table_next_row()
                for (col in range(3)) {
                    table_set_column_index(col)
                    let key = row * 3 + col
                    let cell_text = "Hello {col},{row}"
                    if (TABLES_BORDERS_CONTENTS.value == 0) {
                        text(TABLES_BORDERS_T1_CELL_TEXT[key], (text = cell_text))
                    } else {
                        button(TABLES_BORDERS_T1_CELL_BTN[key],
                               (text = cell_text, size = float2(-1.0f, 0.0f)))
                    }
                }
            }
        }
    }
}

// =============================================================================
// Section 3: Resizable, stretch — cpp:4332-4359
// =============================================================================
def private show_resizable_stretch() {
    apply_open_action()
    tree_node(TABLES_RSTRETCH, (text = "Resizable, stretch",
                                flags = ImGuiTreeNodeFlags.None)) {
        // SizingStretchSame is the default when ScrollX is off; the two
        // toggles below let you observe the effect of disabling Resizable
        // or BordersV. _Resizable implicitly enables _BordersInnerV.
        edit_checkbox_flags(safe_addr(TABLES_RSTRETCH_FLAGS),
            (id = "TBL_RS_F_RESIZABLE", text = "ImGuiTableFlags_Resizable",
             flags_value = int(ImGuiTableFlags.Resizable)))
        edit_checkbox_flags(safe_addr(TABLES_RSTRETCH_FLAGS),
            (id = "TBL_RS_F_BORDERSV", text = "ImGuiTableFlags_BordersV",
             flags_value = int(ImGuiTableFlags.BordersV)))

        data_table(TABLES_RSTRETCH_T1, (text = "##rs1", columns = 3,
                                        flags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_RSTRETCH_FLAGS)),
                                        outer_size = float2(0.0f, 0.0f),
                                        inner_width = 0.0f)) {
            for (row in range(5)) {
                table_next_row()
                for (col in range(3)) {
                    table_set_column_index(col)
                    text(TABLES_RSTRETCH_CELL[row * 3 + col],
                         (text = "Hello {col},{row}"))
                }
            }
        }
    }
}

// =============================================================================
// Section 4: Resizable, fixed — cpp:4364-4393
// =============================================================================
def private show_resizable_fixed() {
    apply_open_action()
    tree_node(TABLES_RFIXED, (text = "Resizable, fixed",
                              flags = ImGuiTreeNodeFlags.None)) {
        // SizingFixedFit keeps columns at their initial width regardless of
        // available space (subject to NoHostExtendX). Double-click a column
        // border to auto-fit to contents.
        edit_checkbox_flags(safe_addr(TABLES_RFIXED_FLAGS),
            (id = "TBL_RF_F_NOHOST", text = "ImGuiTableFlags_NoHostExtendX",
             flags_value = int(ImGuiTableFlags.NoHostExtendX)))

        data_table(TABLES_RFIXED_T1, (text = "##rf1", columns = 3,
                                      flags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_RFIXED_FLAGS)),
                                      outer_size = float2(0.0f, 0.0f),
                                      inner_width = 0.0f)) {
            for (row in range(5)) {
                table_next_row()
                for (col in range(3)) {
                    table_set_column_index(col)
                    text(TABLES_RFIXED_CELL[row * 3 + col],
                         (text = "Hello {col},{row}"))
                }
            }
        }
    }
}

// =============================================================================
// Section 5: Resizable, mixed — cpp:4398-4443
// =============================================================================
def private show_resizable_mixed() {
    apply_open_action()
    tree_node(TABLES_RMIXED, (text = "Resizable, mixed",
                              flags = ImGuiTreeNodeFlags.None)) {
        // Per-column WidthFixed / WidthStretch policy mix. The 6-col second
        // table also demonstrates DefaultHide for initial column visibility.
        let tflags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_RMIXED_FLAGS))

        // Table 1: 3 columns (2 Fixed + 1 Stretch).
        data_table(TABLES_RMIXED_T1, (text = "##rm1", columns = 3, flags = tflags,
                                      outer_size = float2(0.0f, 0.0f),
                                      inner_width = 0.0f)) {
            table_setup_column("AAA", ImGuiTableColumnFlags.WidthFixed)
            table_setup_column("BBB", ImGuiTableColumnFlags.WidthFixed)
            table_setup_column("CCC", ImGuiTableColumnFlags.WidthStretch)
            table_headers_row()
            for (row in range(5)) {
                table_next_row()
                for (col in range(3)) {
                    table_set_column_index(col)
                    let kind = col == 2 ? "Stretch" : "Fixed"
                    text(TABLES_RMIXED_T1_CELL[row * 3 + col],
                         (text = "{kind} {col},{row}"))
                }
            }
        }

        // Table 2: 6 columns (3 Fixed including DefaultHide + 3 Stretch
        // including DefaultHide).
        data_table(TABLES_RMIXED_T2, (text = "##rm2", columns = 6, flags = tflags,
                                      outer_size = float2(0.0f, 0.0f),
                                      inner_width = 0.0f)) {
            table_setup_column("AAA", ImGuiTableColumnFlags.WidthFixed)
            table_setup_column("BBB", ImGuiTableColumnFlags.WidthFixed)
            table_setup_column("CCC", ImGuiTableColumnFlags.WidthFixed | ImGuiTableColumnFlags.DefaultHide)
            table_setup_column("DDD", ImGuiTableColumnFlags.WidthStretch)
            table_setup_column("EEE", ImGuiTableColumnFlags.WidthStretch)
            table_setup_column("FFF", ImGuiTableColumnFlags.WidthStretch | ImGuiTableColumnFlags.DefaultHide)
            table_headers_row()
            for (row in range(5)) {
                table_next_row()
                for (col in range(6)) {
                    table_set_column_index(col)
                    let kind = col >= 3 ? "Stretch" : "Fixed"
                    text(TABLES_RMIXED_T2_CELL[row * 6 + col],
                         (text = "{kind} {col},{row}"))
                }
            }
        }
    }
}

// =============================================================================
// Section 6: Reorderable, hideable, with headers — cpp:4448-4503
// =============================================================================
def private show_reorderable_hideable_headers() {
    apply_open_action()
    tree_node(TABLES_RHH, (text = "Reorderable, hideable, with headers",
                           flags = ImGuiTreeNodeFlags.None)) {
        // Click + drag a header to reorder columns; right-click a header for
        // the visibility context menu.
        edit_checkbox_flags(safe_addr(TABLES_RHH_FLAGS),
            (id = "TBL_RHH_F_RESIZABLE", text = "ImGuiTableFlags_Resizable",
             flags_value = int(ImGuiTableFlags.Resizable)))
        edit_checkbox_flags(safe_addr(TABLES_RHH_FLAGS),
            (id = "TBL_RHH_F_REORDERABLE", text = "ImGuiTableFlags_Reorderable",
             flags_value = int(ImGuiTableFlags.Reorderable)))
        edit_checkbox_flags(safe_addr(TABLES_RHH_FLAGS),
            (id = "TBL_RHH_F_HIDEABLE", text = "ImGuiTableFlags_Hideable",
             flags_value = int(ImGuiTableFlags.Hideable)))
        edit_checkbox_flags(safe_addr(TABLES_RHH_FLAGS),
            (id = "TBL_RHH_F_NBINBODY", text = "ImGuiTableFlags_NoBordersInBody",
             flags_value = int(ImGuiTableFlags.NoBordersInBody)))
        edit_checkbox_flags(safe_addr(TABLES_RHH_FLAGS),
            (id = "TBL_RHH_F_NBINBODYUNTILRESIZE",
             text = "ImGuiTableFlags_NoBordersInBodyUntilResize",
             flags_value = int(ImGuiTableFlags.NoBordersInBodyUntilResize)))
        edit_checkbox_flags(safe_addr(TABLES_RHH_FLAGS),
            (id = "TBL_RHH_F_HIGHLIGHTHOVERED",
             text = "ImGuiTableFlags_HighlightHoveredColumn",
             flags_value = int(ImGuiTableFlags.HighlightHoveredColumn)))

        let tflags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_RHH_FLAGS))

        // Table 1: default outer_size (stretches to fill available width).
        data_table(TABLES_RHH_T1, (text = "##rhh1", columns = 3, flags = tflags,
                                   outer_size = float2(0.0f, 0.0f),
                                   inner_width = 0.0f)) {
            table_setup_column("One")
            table_setup_column("Two")
            table_setup_column("Three")
            table_headers_row()
            for (row in range(6)) {
                table_next_row()
                for (col in range(3)) {
                    table_set_column_index(col)
                    text(TABLES_RHH_T1_CELL[row * 3 + col],
                         (text = "Hello {col},{row}"))
                }
            }
        }

        // Table 2: outer_size.x = 0.0f + SizingFixedFit packs columns tight
        // (valid only without ScrollX or stretch columns).
        let tflags2 = unsafe(reinterpret<ImGuiTableFlags>(
                                 TABLES_RHH_FLAGS | int(ImGuiTableFlags.SizingFixedFit)))
        data_table(TABLES_RHH_T2, (text = "##rhh2", columns = 3, flags = tflags2,
                                   outer_size = float2(0.0f, 0.0f),
                                   inner_width = 0.0f)) {
            table_setup_column("One")
            table_setup_column("Two")
            table_setup_column("Three")
            table_headers_row()
            for (row in range(6)) {
                table_next_row()
                for (col in range(3)) {
                    table_set_column_index(col)
                    text(TABLES_RHH_T2_CELL[row * 3 + col],
                         (text = "Fixed {col},{row}"))
                }
            }
        }
    }
}
