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
require math

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

// ---- Section 7 Padding state ----
// Two sub-tables: table_padding (flag toggles + Avail/FillButton cells)
// and table_padding_2 (CellPadding style-var + InputText grid).
var private TABLES_PAD1_FLAGS : int = int(ImGuiTableFlags.BordersV)
var private TABLES_PAD1_AVAIL : table<int; NarrativeState>  // row 0 cells: "Avail %.2f"
var private TABLES_PAD1_BTN   : table<int; ClickState>      // rows 1-4 cells: FillButton "Hello c,r"

var private TABLES_PAD2_FLAGS        : int    = int(ImGuiTableFlags.Borders | ImGuiTableFlags.RowBg)
var private TABLES_PAD2_CELL_PADDING : float2 = float2(0.0f, 0.0f)
// 15 InputText cells; the boost (text=..., init=...) named-tuple form
// seeds the buffer to "edit me" on first call (matches cpp's static init).
var private TABLES_PAD2_CELL_IT      : table<int; InputTextState>

// ---- Section 8 Sizing policies state ----
// Quad of mini-tables, each with its own SizingFixed*/SizingStretch*
// policy. The cpp helper EditTableSizingFlags is ported as
// `def private edit_table_sizing_flags` below; it splices the policy bits
// in/out of an int-typed flag word.
var private TABLES_SIZING_FLAGS1 : int = int(ImGuiTableFlags.Resizable |
                                             ImGuiTableFlags.NoHostExtendX)
// Policy-per-row state: 4 outer iterations, each owns one flag word
// (initialized via [init] to the 4 cpp defaults) plus two 3-col x 3-row
// inner tables of NarrativeState cells.
var private TABLES_SIZING_POLICY      : table<int; int>
var private TABLES_SIZING_T1          : table<int; TableState>      // 4 data_tables
var private TABLES_SIZING_T2          : table<int; TableState>      // 4 data_tables
var private TABLES_SIZING_T1_CELL     : table<int; NarrativeState>  // key = table_n*9 + row*3 + col
var private TABLES_SIZING_T2_CELL     : table<int; NarrativeState>

// Advanced sub-block: flag toggles + dynamic-column body. CT_ enum is
// mirrored as ints to match the cpp `static int contents_type`.
let private TABLES_SIZING_CT_SHOW_WIDTH    = 0
let private TABLES_SIZING_CT_SHORT_TEXT    = 1
let private TABLES_SIZING_CT_LONG_TEXT     = 2
let private TABLES_SIZING_CT_BUTTON        = 3
let private TABLES_SIZING_CT_FILL_BUTTON   = 4
let private TABLES_SIZING_CT_INPUT_TEXT    = 5

var private TABLES_SIZING_ADV_FLAGS : int = int(ImGuiTableFlags.ScrollY |
                                                ImGuiTableFlags.Borders |
                                                ImGuiTableFlags.RowBg |
                                                ImGuiTableFlags.Resizable)
var private TABLES_SIZING_ADV_CT       : int = 0
var private TABLES_SIZING_ADV_COLUMNS  : int = 3
// Per-CT-type cell maps so widget registry paths stay disjoint when the
// user flips contents_type at runtime (avoids state-shape mismatch).
var private TABLES_SIZING_ADV_TEXT    : table<int; NarrativeState>
var private TABLES_SIZING_ADV_BTN     : table<int; ClickState>
var private TABLES_SIZING_ADV_IT      : table<int; InputTextState>

// ---- Section 9 Vertical scrolling state ----
var private TABLES_VSCROLL_FLAGS : int = int(ImGuiTableFlags.ScrollY |
                                             ImGuiTableFlags.RowBg |
                                             ImGuiTableFlags.BordersOuter |
                                             ImGuiTableFlags.BordersV |
                                             ImGuiTableFlags.Resizable |
                                             ImGuiTableFlags.Reorderable |
                                             ImGuiTableFlags.Hideable)
var private TABLES_VSCROLL_CELL : table<int; NarrativeState>  // key = row*3 + col, 1000 rows

// ---- Section 10 Horizontal scrolling state ----
var private TABLES_HSCROLL_FLAGS : int = int(ImGuiTableFlags.ScrollX |
                                             ImGuiTableFlags.ScrollY |
                                             ImGuiTableFlags.RowBg |
                                             ImGuiTableFlags.BordersOuter |
                                             ImGuiTableFlags.BordersV |
                                             ImGuiTableFlags.Resizable |
                                             ImGuiTableFlags.Reorderable |
                                             ImGuiTableFlags.Hideable)
var private TABLES_HSCROLL_FREEZE_COLS : int = 1
var private TABLES_HSCROLL_FREEZE_ROWS : int = 1
var private TABLES_HSCROLL_CELL : table<int; NarrativeState>  // 20 rows x 7 cols

// Second sub-table (Stretch + ScrollX).
var private TABLES_HSCROLL2_FLAGS : int = int(ImGuiTableFlags.SizingStretchSame |
                                              ImGuiTableFlags.ScrollX |
                                              ImGuiTableFlags.ScrollY |
                                              ImGuiTableFlags.BordersOuter |
                                              ImGuiTableFlags.RowBg |
                                              ImGuiTableFlags.ContextMenuInBody)
var private TABLES_HSCROLL2_INNER_WIDTH : float = 1000.0f
var private TABLES_HSCROLL2_CELL : table<int; NarrativeState>  // 20*7 cells

// ---- Section 11 Columns flags state ----
// Per-column input flags (DefaultSort / None / DefaultHide) — int-backed
// so edit_checkbox_flags can edit them; reinterpreted to
// ImGuiTableColumnFlags at TableSetupColumn time.
var private TABLES_COLFLAGS_INPUT     : table<int; int>     // 3 columns
// Output flags read from TableGetColumnFlags per frame; displayed in the
// first sub-table via a disabled set of CheckboxFlags.
var private TABLES_COLFLAGS_OUTPUT    : table<int; int>     // 3 columns
var private TABLES_COLFLAGS_BODY_CELL : table<int; NarrativeState>  // 8*3 cells in body table

// Per-column widget state for the setup-table's label cells: 1 label per
// column → 3 each. Indexed so widget paths stay per-column-distinct.
var private TABLES_COLFLAGS_ATFP          : table<int; EmptyMarkerState>
var private TABLES_COLFLAGS_LABEL         : table<int; NarrativeState>
var private TABLES_COLFLAGS_INFLAG_LABEL  : table<int; NarrativeState>
var private TABLES_COLFLAGS_OUTFLAG_LABEL : table<int; NarrativeState>

// ---- Section 12 Columns widths state ----
// Sub-table 1: default-width via TableSetupColumn (cpp:4938-4967).
var private TABLES_CW1_FLAGS : int = int(ImGuiTableFlags.Borders |
                                         ImGuiTableFlags.NoBordersInBodyUntilResize)
var private TABLES_CW1_CELL : table<int; NarrativeState>  // 4*3 cells
// Sub-table 2: explicit-width via TableSetupColumn (cpp:4969-5000).
var private TABLES_CW2_FLAGS : int = int(ImGuiTableFlags.None)
var private TABLES_CW2_CELL : table<int; NarrativeState>  // 5*4 cells

// ---- Section 13 Nested tables state ----
// One outer 2-col table holding a nested 2-col table in its first cell.
var private TABLES_NESTED_OUTER_CELL : table<int; NarrativeState>  // 4 cells
var private TABLES_NESTED_INNER_CELL : table<int; NarrativeState>  // 4 cells

// ---- Section 14 Row height state ----
// Sub 1: variable min_row_height per row.
var private TABLES_RH1_CELL : table<int; NarrativeState>  // 8 cells
// Sub 2: SameLine(0,0) line-height share — two rows, ColorButton + 2-line text.
var private TABLES_RH2_COLOR_BTN : table<int; ClickState>     // 2 cells
var private TABLES_RH2_LINE1     : table<int; NarrativeState> // 2 cells
var private TABLES_RH2_LINE2     : table<int; NarrativeState> // 2 cells
// Sub 3: per-row CellPadding.y mutation (every 3rd row).
var private TABLES_RH3_CELL : table<int; NarrativeState>  // 8 cells

// ---- Section 15 Outer size state ----
// Sub 1: NoHostExtendX/Y toggles + sliding "Hello!" SameLine target.
var private TABLES_OS1_FLAGS : int = int(ImGuiTableFlags.Borders |
                                         ImGuiTableFlags.Resizable |
                                         ImGuiTableFlags.ContextMenuInBody |
                                         ImGuiTableFlags.RowBg |
                                         ImGuiTableFlags.SizingFixedFit |
                                         ImGuiTableFlags.NoHostExtendX)
var private TABLES_OS1_CELL : table<int; NarrativeState>  // 10*3 cells
// Sub 2 + 3: two explicit-size tables side-by-side.
var private TABLES_OS2_CELL : table<int; NarrativeState>  // 5*3 cells
var private TABLES_OS3_CELL : table<int; NarrativeState>  // 3*3 cells

[init]
def seed_columns_flags() {
    // cpp:4868 — `column_flags[3] = { DefaultSort, None, DefaultHide }`.
    TABLES_COLFLAGS_INPUT[0] = int(ImGuiTableColumnFlags.DefaultSort)
    TABLES_COLFLAGS_INPUT[1] = int(ImGuiTableColumnFlags.None)
    TABLES_COLFLAGS_INPUT[2] = int(ImGuiTableColumnFlags.DefaultHide)
}

[init]
def seed_padding_cells() {
    // Pre-populate the 15-cell InputText buffer with "edit me" to mirror
    // the cpp static char text_bufs[3*5][16] + init flag pattern. The
    // boost init= named-tuple sugar isn't supported on indexed [widget]
    // form (per the macro's named-init-on-indexed-form diagnostic), so
    // direct field set in [init] is the documented workaround.
    for (i in range(15)) {
        TABLES_PAD2_CELL_IT[i].value := "edit me"
    }
}

[init]
def seed_sizing_policy() {
    // Mirrors `static ImGuiTableFlags sizing_policy_flags[4]` in cpp:4626.
    // Per-iteration table_n is the index into this map; the body OR's the
    // chosen policy with TABLES_SIZING_FLAGS1 before BeginTable.
    TABLES_SIZING_POLICY[0] = int(ImGuiTableFlags.SizingFixedFit)
    TABLES_SIZING_POLICY[1] = int(ImGuiTableFlags.SizingFixedSame)
    TABLES_SIZING_POLICY[2] = int(ImGuiTableFlags.SizingStretchProp)
    TABLES_SIZING_POLICY[3] = int(ImGuiTableFlags.SizingStretchSame)
}

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
        show_padding()
        show_sizing_policies()
        show_vertical_scrolling()
        show_horizontal_scrolling()
        show_columns_flags()
        show_columns_widths()
        show_nested_tables()
        show_row_height()
        show_outer_size()

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

// =============================================================================
// Section 7: Padding — cpp:4508-4613
// =============================================================================
def private show_padding_inputtext_grid() {
    // Body extracted so the outer conditional FrameBg push wraps a single
    // call (instead of duplicating the 15-cell loop in each branch). Each
    // cell's own (text, init) seeds the buffer to "edit me" on first call.
    for (cell in range(15)) {
        table_next_column()
        SetNextItemWidth(-FLT_MIN)
        input_text(TABLES_PAD2_CELL_IT[cell], (text = "##cell"))
    }
}

def private show_padding() {
    apply_open_action()
    tree_node(TABLES_PADDING, (text = "Padding",
                               flags = ImGuiTreeNodeFlags.None)) {
        // ----- Sub-table 1: padding-flag effect on X spacing -----
        // PadOuterX / NoPadOuterX / NoPadInnerX + BordersOuterV/InnerV.
        // The first row's cell reads ContentRegionAvail.x so the
        // available-width effect of each toggle is visible at a glance.
        edit_checkbox_flags(safe_addr(TABLES_PAD1_FLAGS),
            (id = "TBL_P1_F_PAD_OUT_X", text = "ImGuiTableFlags_PadOuterX",
             flags_value = int(ImGuiTableFlags.PadOuterX)))
        edit_checkbox_flags(safe_addr(TABLES_PAD1_FLAGS),
            (id = "TBL_P1_F_NOPAD_OUT_X", text = "ImGuiTableFlags_NoPadOuterX",
             flags_value = int(ImGuiTableFlags.NoPadOuterX)))
        edit_checkbox_flags(safe_addr(TABLES_PAD1_FLAGS),
            (id = "TBL_P1_F_NOPAD_IN_X", text = "ImGuiTableFlags_NoPadInnerX",
             flags_value = int(ImGuiTableFlags.NoPadInnerX)))
        edit_checkbox_flags(safe_addr(TABLES_PAD1_FLAGS),
            (id = "TBL_P1_F_BORDERS_OV", text = "ImGuiTableFlags_BordersOuterV",
             flags_value = int(ImGuiTableFlags.BordersOuterV)))
        edit_checkbox_flags(safe_addr(TABLES_PAD1_FLAGS),
            (id = "TBL_P1_F_BORDERS_IV", text = "ImGuiTableFlags_BordersInnerV",
             flags_value = int(ImGuiTableFlags.BordersInnerV)))
        checkbox(TABLES_PAD1_SHOW_HEADERS, (text = "show_headers", init = false))

        data_table(TABLES_PAD1_T, (text = "##pad1", columns = 3,
                                   flags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_PAD1_FLAGS)),
                                   outer_size = float2(0.0f, 0.0f),
                                   inner_width = 0.0f)) {
            if (TABLES_PAD1_SHOW_HEADERS.value) {
                table_setup_column("One")
                table_setup_column("Two")
                table_setup_column("Three")
                table_headers_row()
            }
            for (row in range(5)) {
                table_next_row()
                for (col in range(3)) {
                    table_set_column_index(col)
                    if (row == 0) {
                        let avail = GetContentRegionAvail().x
                        text(TABLES_PAD1_AVAIL[col],
                             (text = "Avail {avail}"))
                    } else {
                        let key = (row - 1) * 3 + col
                        button(TABLES_PAD1_BTN[key],
                               (text = "Hello {col},{row}",
                                size = float2(-FLT_MIN, 0.0f)))
                    }
                }
            }
        }

        // ----- Sub-table 2: explicit CellPadding style-var -----
        // Sliderable CellPadding (0..10, %.0f) overrides ImGuiStyle for the
        // wrapped data_table call. Optional FrameBg=0 push hides the per-
        // InputText frame so the cell padding is visually unambiguous.
        edit_checkbox_flags(safe_addr(TABLES_PAD2_FLAGS),
            (id = "TBL_P2_F_BORDERS", text = "ImGuiTableFlags_Borders",
             flags_value = int(ImGuiTableFlags.Borders)))
        edit_checkbox_flags(safe_addr(TABLES_PAD2_FLAGS),
            (id = "TBL_P2_F_BORDERSH", text = "ImGuiTableFlags_BordersH",
             flags_value = int(ImGuiTableFlags.BordersH)))
        edit_checkbox_flags(safe_addr(TABLES_PAD2_FLAGS),
            (id = "TBL_P2_F_BORDERSV", text = "ImGuiTableFlags_BordersV",
             flags_value = int(ImGuiTableFlags.BordersV)))
        edit_checkbox_flags(safe_addr(TABLES_PAD2_FLAGS),
            (id = "TBL_P2_F_BORDERS_IN", text = "ImGuiTableFlags_BordersInner",
             flags_value = int(ImGuiTableFlags.BordersInner)))
        edit_checkbox_flags(safe_addr(TABLES_PAD2_FLAGS),
            (id = "TBL_P2_F_BORDERS_OUT", text = "ImGuiTableFlags_BordersOuter",
             flags_value = int(ImGuiTableFlags.BordersOuter)))
        edit_checkbox_flags(safe_addr(TABLES_PAD2_FLAGS),
            (id = "TBL_P2_F_ROWBG", text = "ImGuiTableFlags_RowBg",
             flags_value = int(ImGuiTableFlags.RowBg)))
        edit_checkbox_flags(safe_addr(TABLES_PAD2_FLAGS),
            (id = "TBL_P2_F_RESIZABLE", text = "ImGuiTableFlags_Resizable",
             flags_value = int(ImGuiTableFlags.Resizable)))
        checkbox(TABLES_PAD2_SHOW_FRAMEBG, (text = "show_widget_frame_bg", init = true))
        edit_slider_float2(safe_addr(TABLES_PAD2_CELL_PADDING),
            (id = "TBL_P2_CELL_PAD", text = "CellPadding",
             v_min = 0.0f, v_max = 10.0f, format = "%.0f"))

        with_style((ImGuiStyleVar.CellPadding, TABLES_PAD2_CELL_PADDING)) {
            data_table(TABLES_PAD2_T, (text = "##pad2", columns = 3,
                                       flags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_PAD2_FLAGS)),
                                       outer_size = float2(0.0f, 0.0f),
                                       inner_width = 0.0f)) {
                if (!TABLES_PAD2_SHOW_FRAMEBG.value) {
                    with_style((ImGuiCol.FrameBg, 0u)) {
                        show_padding_inputtext_grid()
                    }
                } else {
                    show_padding_inputtext_grid()
                }
            }
        }
    }
}

// =============================================================================
// Section 8: Sizing policies — cpp:4618-4722
// =============================================================================
// cpp helper `EditTableSizingFlags(ImGuiTableFlags*)` ported as a private
// def. Strips the four `SizingFixed*`/`SizingStretch*` policy bits out of
// the input flags, lets the user pick one via a Combo, and ORs it back in.
// Pure-bits manipulation — no widget IDENT needed beyond the Combo state.
def private edit_table_sizing_flags(var p_flags : int? implicit; id : string) {
    let policy_mask = int(ImGuiTableFlags.SizingMask_)
    let values = fixed_array(int(ImGuiTableFlags.None),
                             int(ImGuiTableFlags.SizingFixedFit),
                             int(ImGuiTableFlags.SizingFixedSame),
                             int(ImGuiTableFlags.SizingStretchProp),
                             int(ImGuiTableFlags.SizingStretchSame))
    var current = 0
    unsafe { current = *p_flags & policy_mask; }
    var idx = 0
    for (n in range(5)) {
        if (values[n] == current) {
            idx = n
            break
        }
    }
    // Per-call PushID scope so the same Combo IDENT can fire under each
    // caller. cpp:4095 also drops "ImGuiTableFlags" from the preview text,
    // but the boost `edit_combo` shows the selected item's full label —
    // close enough; the full names below are self-documenting.
    with_id(id) {
        var items <- ["Default",
                      "ImGuiTableFlags_SizingFixedFit",
                      "ImGuiTableFlags_SizingFixedSame",
                      "ImGuiTableFlags_SizingStretchProp",
                      "ImGuiTableFlags_SizingStretchSame"]
        var local_idx = idx
        if (edit_combo(unsafe(addr(local_idx)),
                       (id = "SIZING_POLICY_COMBO", text = "Sizing Policy",
                        items = items))) {
            unsafe { *p_flags = (*p_flags & ~policy_mask) | values[local_idx]; }
        }
        delete items
    }
}

def private show_sizing_policies() {
    apply_open_action()
    tree_node(TABLES_SIZING, (text = "Sizing policies",
                              flags = ImGuiTreeNodeFlags.None)) {
        // Shared flag toggles applied on top of each per-row policy.
        edit_checkbox_flags(safe_addr(TABLES_SIZING_FLAGS1),
            (id = "TBL_SZ_F_RESIZABLE", text = "ImGuiTableFlags_Resizable",
             flags_value = int(ImGuiTableFlags.Resizable)))
        edit_checkbox_flags(safe_addr(TABLES_SIZING_FLAGS1),
            (id = "TBL_SZ_F_NOHOST", text = "ImGuiTableFlags_NoHostExtendX",
             flags_value = int(ImGuiTableFlags.NoHostExtendX)))

        // Four mini-tables, one per sizing policy. Equal-width + uneven-
        // width content side-by-side so the policy effect is visually
        // unambiguous. Per-table PushID via with_id("sizing_n") keeps the
        // Combo IDs disjoint when the same edit_table_sizing_flags helper
        // fires four times.
        for (table_n in range(4)) {
            with_id("sizing_{table_n}") {
                SetNextItemWidth(GetFontSize() * 30.0f)
                edit_table_sizing_flags(unsafe(addr(TABLES_SIZING_POLICY[table_n])),
                                        "sizing_{table_n}")

                let combined = unsafe(reinterpret<ImGuiTableFlags>(
                    TABLES_SIZING_POLICY[table_n] | TABLES_SIZING_FLAGS1))

                // Table 1: equal-width content ("Oh dear" x 3 across 3 cols).
                data_table(TABLES_SIZING_T1[table_n],
                           (text = "##sz1_{table_n}", columns = 3,
                            flags = combined,
                            outer_size = float2(0.0f, 0.0f),
                            inner_width = 0.0f)) {
                    for (row in range(3)) {
                        table_next_row()
                        let base = table_n * 9 + row * 3
                        for (col in range(3)) {
                            table_next_column()
                            text(TABLES_SIZING_T1_CELL[base + col],
                                 (text = "Oh dear"))
                        }
                    }
                }

                // Table 2: ragged-width content (AAAA / BBBBBBBB / CCCCCCCCCCCC).
                data_table(TABLES_SIZING_T2[table_n],
                           (text = "##sz2_{table_n}", columns = 3,
                            flags = combined,
                            outer_size = float2(0.0f, 0.0f),
                            inner_width = 0.0f)) {
                    let labels = fixed_array("AAAA", "BBBBBBBB", "CCCCCCCCCCCC")
                    for (row in range(3)) {
                        table_next_row()
                        let base = table_n * 9 + row * 3
                        for (col in range(3)) {
                            table_next_column()
                            text(TABLES_SIZING_T2_CELL[base + col],
                                 (text = labels[col]))
                        }
                    }
                }
            }
        }

        // ----- Advanced sub-block -----
        text(TABLES_SIZING_ADV_LABEL, (text = "Advanced"))
        with_id("sizing_advanced") {
            SetNextItemWidth(GetFontSize() * 30.0f)
            edit_table_sizing_flags(safe_addr(TABLES_SIZING_ADV_FLAGS),
                                    "sizing_adv_combo")

            // Contents-type Combo (CT enum mirror).
            var ct_items <- ["Show width", "Short Text", "Long Text",
                             "Button", "Fill Button", "InputText"]
            edit_combo(safe_addr(TABLES_SIZING_ADV_CT),
                       (id = "TBL_SZ_ADV_CT", text = "Contents",
                        items = ct_items))
            delete ct_items

            edit_drag_int(safe_addr(TABLES_SIZING_ADV_COLUMNS),
                (id = "TBL_SZ_ADV_COLS", text = "Columns",
                 speed = 0.1f, v_min = 1, v_max = 64, format = "%d",
                 flags = ImGuiSliderFlags.AlwaysClamp))
            edit_checkbox_flags(safe_addr(TABLES_SIZING_ADV_FLAGS),
                (id = "TBL_SZ_ADV_F_RESIZABLE",
                 text = "ImGuiTableFlags_Resizable",
                 flags_value = int(ImGuiTableFlags.Resizable)))
            edit_checkbox_flags(safe_addr(TABLES_SIZING_ADV_FLAGS),
                (id = "TBL_SZ_ADV_F_PRECISE",
                 text = "ImGuiTableFlags_PreciseWidths",
                 flags_value = int(ImGuiTableFlags.PreciseWidths)))
            edit_checkbox_flags(safe_addr(TABLES_SIZING_ADV_FLAGS),
                (id = "TBL_SZ_ADV_F_SCROLLX",
                 text = "ImGuiTableFlags_ScrollX",
                 flags_value = int(ImGuiTableFlags.ScrollX)))
            edit_checkbox_flags(safe_addr(TABLES_SIZING_ADV_FLAGS),
                (id = "TBL_SZ_ADV_F_SCROLLY",
                 text = "ImGuiTableFlags_ScrollY",
                 flags_value = int(ImGuiTableFlags.ScrollY)))
            edit_checkbox_flags(safe_addr(TABLES_SIZING_ADV_FLAGS),
                (id = "TBL_SZ_ADV_F_NOCLIP",
                 text = "ImGuiTableFlags_NoClip",
                 flags_value = int(ImGuiTableFlags.NoClip)))

            let col_count = max(TABLES_SIZING_ADV_COLUMNS, 1)
            let line_height = GetTextLineHeightWithSpacing()
            data_table(TABLES_SIZING_ADV_T,
                       (text = "##sz_adv", columns = col_count,
                        flags = unsafe(reinterpret<ImGuiTableFlags>(
                                           TABLES_SIZING_ADV_FLAGS)),
                        outer_size = float2(0.0f, line_height * 7.0f),
                        inner_width = 0.0f)) {
                for (cell in range(10 * col_count)) {
                    table_next_column()
                    let column = table_get_column_index()
                    let row = table_get_row_index()
                    let cell_label = "Hello {column},{row}"
                    if (TABLES_SIZING_ADV_CT == TABLES_SIZING_CT_SHORT_TEXT) {
                        text(TABLES_SIZING_ADV_TEXT[cell], (text = cell_label))
                    } elif (TABLES_SIZING_ADV_CT == TABLES_SIZING_CT_LONG_TEXT) {
                        let adj = column == 0 ? "long" : "longeeer"
                        text(TABLES_SIZING_ADV_TEXT[cell],
                             (text = "Some {adj} text {column},{row}\nOver two lines.."))
                    } elif (TABLES_SIZING_ADV_CT == TABLES_SIZING_CT_SHOW_WIDTH) {
                        let avail = GetContentRegionAvail().x
                        text(TABLES_SIZING_ADV_TEXT[cell],
                             (text = "W: {avail}"))
                    } elif (TABLES_SIZING_ADV_CT == TABLES_SIZING_CT_BUTTON) {
                        button(TABLES_SIZING_ADV_BTN[cell],
                               (text = cell_label, size = float2(0.0f, 0.0f)))
                    } elif (TABLES_SIZING_ADV_CT == TABLES_SIZING_CT_FILL_BUTTON) {
                        button(TABLES_SIZING_ADV_BTN[cell],
                               (text = cell_label, size = float2(-FLT_MIN, 0.0f)))
                    } elif (TABLES_SIZING_ADV_CT == TABLES_SIZING_CT_INPUT_TEXT) {
                        SetNextItemWidth(-FLT_MIN)
                        input_text(TABLES_SIZING_ADV_IT[cell], (text = "##sz_adv_it"))
                    }
                }
            }
        }
    }
}

// =============================================================================
// Section 9: Vertical scrolling, with clipping — cpp:4727-4771
// =============================================================================
def private show_vertical_scrolling() {
    apply_open_action()
    tree_node(TABLES_VSCROLL, (text = "Vertical scrolling, with clipping",
                               flags = ImGuiTreeNodeFlags.None)) {
        // ScrollY toggle.
        edit_checkbox_flags(safe_addr(TABLES_VSCROLL_FLAGS),
            (id = "TBL_VS_F_SCROLLY", text = "ImGuiTableFlags_ScrollY",
             flags_value = int(ImGuiTableFlags.ScrollY)))

        // Outer size MUST be specified when ScrollX/ScrollY is on, or the
        // table fills the host like a child window.
        let line_height = GetTextLineHeightWithSpacing()
        let outer_size = float2(0.0f, line_height * 8.0f)
        data_table(TABLES_VSCROLL_T,
                   (text = "##table_scrolly", columns = 3,
                    flags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_VSCROLL_FLAGS)),
                    outer_size = outer_size,
                    inner_width = 0.0f)) {
            table_setup_scroll_freeze(0, 1) // pin the header row
            table_setup_column("One")
            table_setup_column("Two")
            table_setup_column("Three")
            table_headers_row()

            // 1000 rows via list_clipper — only the visible window is
            // submitted per frame. The boost wrapper hides the
            // `clipper.Begin/.Step` ceremony.
            list_clipper(1000) $(start, end_) {
                for (row in range(start, end_)) {
                    table_next_row()
                    for (col in range(3)) {
                        table_set_column_index(col)
                        text(TABLES_VSCROLL_CELL[row * 3 + col],
                             (text = "Hello {col},{row}"))
                    }
                }
            }
        }
    }
}

// =============================================================================
// Section 10: Horizontal scrolling — cpp:4772-4861
// =============================================================================
def private show_horizontal_scrolling() {
    apply_open_action()
    tree_node(TABLES_HSCROLL, (text = "Horizontal scrolling",
                               flags = ImGuiTreeNodeFlags.None)) {
        edit_checkbox_flags(safe_addr(TABLES_HSCROLL_FLAGS),
            (id = "TBL_HS_F_RESIZABLE", text = "ImGuiTableFlags_Resizable",
             flags_value = int(ImGuiTableFlags.Resizable)))
        edit_checkbox_flags(safe_addr(TABLES_HSCROLL_FLAGS),
            (id = "TBL_HS_F_SCROLLX", text = "ImGuiTableFlags_ScrollX",
             flags_value = int(ImGuiTableFlags.ScrollX)))
        edit_checkbox_flags(safe_addr(TABLES_HSCROLL_FLAGS),
            (id = "TBL_HS_F_SCROLLY", text = "ImGuiTableFlags_ScrollY",
             flags_value = int(ImGuiTableFlags.ScrollY)))

        SetNextItemWidth(GetFrameHeight())
        edit_drag_int(safe_addr(TABLES_HSCROLL_FREEZE_COLS),
            (id = "TBL_HS_FREEZE_COLS", text = "freeze_cols",
             speed = 0.2f, v_min = 0, v_max = 9, format = "%d",
             flags = ImGuiSliderFlags.NoInput))
        SetNextItemWidth(GetFrameHeight())
        edit_drag_int(safe_addr(TABLES_HSCROLL_FREEZE_ROWS),
            (id = "TBL_HS_FREEZE_ROWS", text = "freeze_rows",
             speed = 0.2f, v_min = 0, v_max = 9, format = "%d",
             flags = ImGuiSliderFlags.NoInput))

        let line_height = GetTextLineHeightWithSpacing()
        let outer_size = float2(0.0f, line_height * 8.0f)
        data_table(TABLES_HSCROLL_T1,
                   (text = "##table_scrollx", columns = 7,
                    flags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_HSCROLL_FLAGS)),
                    outer_size = outer_size,
                    inner_width = 0.0f)) {
            table_setup_scroll_freeze(TABLES_HSCROLL_FREEZE_COLS,
                                      TABLES_HSCROLL_FREEZE_ROWS)
            table_setup_column("Line #", ImGuiTableColumnFlags.NoHide)
            table_setup_column("One")
            table_setup_column("Two")
            table_setup_column("Three")
            table_setup_column("Four")
            table_setup_column("Five")
            table_setup_column("Six")
            table_headers_row()
            for (row in range(20)) {
                table_next_row()
                for (col in range(7)) {
                    // Skip non-visible columns past col 0 (cpp:4819-4820
                    // optimization — relies on col 0 always visible because
                    // of the freeze + NoHide).
                    continue if (!table_set_column_index(col) && col > 0)
                    if (col == 0) {
                        text(TABLES_HSCROLL_CELL[row * 7 + col],
                             (text = "Line {row}"))
                    } else {
                        text(TABLES_HSCROLL_CELL[row * 7 + col],
                             (text = "Hello world {col},{row}"))
                    }
                }
            }
        }

        spacing()
        text(TABLES_HSCROLL2_LABEL, (text = "Stretch + ScrollX"))

        with_id("hscroll2") {
            with_item_width(GetFontSize() * 30.0f) {
                edit_checkbox_flags(safe_addr(TABLES_HSCROLL2_FLAGS),
                    (id = "TBL_HS2_F_SCROLLX", text = "ImGuiTableFlags_ScrollX",
                     flags_value = int(ImGuiTableFlags.ScrollX)))
                edit_drag_float(safe_addr(TABLES_HSCROLL2_INNER_WIDTH),
                    (id = "TBL_HS2_INNER_WIDTH", text = "inner_width",
                     v_speed = 1.0f, v_min = 0.0f, v_max = FLT_MAX,
                     format = "%.1f"))
            }
            data_table(TABLES_HSCROLL2_T,
                       (text = "##table_hscroll2", columns = 7,
                        flags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_HSCROLL2_FLAGS)),
                        outer_size = outer_size,
                        inner_width = TABLES_HSCROLL2_INNER_WIDTH)) {
                for (cell in range(20 * 7)) {
                    table_next_column()
                    let col = table_get_column_index()
                    let row = table_get_row_index()
                    text(TABLES_HSCROLL2_CELL[cell],
                         (text = "Hello world {col},{row}"))
                }
            }
        }
    }
}

// =============================================================================
// Section 11: Columns flags — cpp:4862-4933
// =============================================================================
def private show_columns_flags() {
    apply_open_action()
    tree_node(TABLES_COLFLAGS, (text = "Columns flags",
                                flags = ImGuiTreeNodeFlags.None)) {
        let column_count = 3
        let column_names = fixed_array("One", "Two", "Three")

        // ----- Setup-table: per-column flag editors + output status display -----
        data_table(TABLES_COLFLAGS_SETUP_T,
                   (text = "##colflags_checkboxes", columns = column_count,
                    flags = ImGuiTableFlags.None,
                    outer_size = float2(0.0f, 0.0f),
                    inner_width = 0.0f)) {
            for (column in range(column_count)) {
                table_next_column()
                with_id("colflags_col_{column}") {
                    align_text_to_frame_padding(TABLES_COLFLAGS_ATFP[column])
                    text(TABLES_COLFLAGS_LABEL[column],
                         (text = "'{column_names[column]}'"))
                    spacing()
                    text(TABLES_COLFLAGS_INFLAG_LABEL[column],
                         (text = "Input flags:"))
                    edit_column_flags(unsafe(addr(TABLES_COLFLAGS_INPUT[column])))
                    spacing()
                    text(TABLES_COLFLAGS_OUTFLAG_LABEL[column],
                         (text = "Output flags:"))
                    with_disabled(true) {
                        show_column_status_flags(TABLES_COLFLAGS_OUTPUT[column])
                    }
                }
            }
        }

        // ----- Real table — body driven by the per-column flag input -----
        let flags = (ImGuiTableFlags.SizingFixedFit | ImGuiTableFlags.ScrollX |
                     ImGuiTableFlags.ScrollY | ImGuiTableFlags.RowBg |
                     ImGuiTableFlags.BordersOuter | ImGuiTableFlags.BordersV |
                     ImGuiTableFlags.Resizable | ImGuiTableFlags.Reorderable |
                     ImGuiTableFlags.Hideable | ImGuiTableFlags.Sortable)
        let line_height = GetTextLineHeightWithSpacing()
        let outer_size = float2(0.0f, line_height * 9.0f)
        let text_base_width = CalcTextSize("A").x

        data_table(TABLES_COLFLAGS_BODY_T,
                   (text = "##colflags_body", columns = column_count,
                    flags = flags,
                    outer_size = outer_size,
                    inner_width = 0.0f)) {
            var has_angled_header = false
            for (column in range(column_count)) {
                let col_flags = unsafe(reinterpret<ImGuiTableColumnFlags>(
                                           TABLES_COLFLAGS_INPUT[column]))
                if ((TABLES_COLFLAGS_INPUT[column] &
                     int(ImGuiTableColumnFlags.AngledHeader)) != 0) {
                    has_angled_header = true
                }
                table_setup_column(column_names[column], col_flags)
            }
            if (has_angled_header) {
                table_angled_headers_row()
            }
            table_headers_row()
            for (column in range(column_count)) {
                TABLES_COLFLAGS_OUTPUT[column] = int(table_get_column_flags(column))
            }
            let indent_step = float(int(text_base_width / 2.0f))
            // cpp uses paired `Indent(step)` per row + final
            // `Unindent(step * 8)` to accumulate one extra step at the
            // start of every row. The block-scoped boost wrapper
            // `with_indent(amount)` pops at body exit so accumulation
            // needs an explicit per-row amount: row N starts with
            // `(N + 1) * step` indent worth.
            for (row in range(8)) {
                with_indent(indent_step * float(row + 1)) {
                    table_next_row()
                    for (column in range(column_count)) {
                        table_set_column_index(column)
                        let prefix = column == 0 ? "Indented" : "Hello"
                        let cname = table_get_column_name(column)
                        text(TABLES_COLFLAGS_BODY_CELL[row * column_count + column],
                             (text = "{prefix} {cname}"))
                    }
                }
            }
        }
    }
}

// edit_column_flags — port of cpp `EditTableColumnsFlags(ImGuiTableColumnFlags*)`
// (cpp:4121-4144). 16 checkbox toggles in vertical sequence. The macro
// requires `id =` to be a string literal so we can't splice the column
// index in — instead the caller wraps the call in
// `with_id("colflags_col_{column}")` and we use fixed IDs here. ImGui's
// ID stack hashes the with_id prefix into each IDENT, keeping the
// per-column instances disjoint without per-column IDENT splicing.
// Width/sort mutual-exclusion bits reproduce the cpp `if (Checkbox(...))
// flags &= ~mask` clearing.
def private edit_column_flags(var p_flags : int? implicit) {
    let stretch_mask = (int(ImGuiTableColumnFlags.WidthMask_) ^
                        int(ImGuiTableColumnFlags.WidthStretch))
    let fixed_mask   = (int(ImGuiTableColumnFlags.WidthMask_) ^
                        int(ImGuiTableColumnFlags.WidthFixed))

    edit_checkbox_flags(p_flags, (id = "CF_DIS", text = "_Disabled",
        flags_value = int(ImGuiTableColumnFlags.Disabled)))
    edit_checkbox_flags(p_flags, (id = "CF_DH", text = "_DefaultHide",
        flags_value = int(ImGuiTableColumnFlags.DefaultHide)))
    edit_checkbox_flags(p_flags, (id = "CF_DS", text = "_DefaultSort",
        flags_value = int(ImGuiTableColumnFlags.DefaultSort)))
    if (edit_checkbox_flags(p_flags, (id = "CF_WS", text = "_WidthStretch",
        flags_value = int(ImGuiTableColumnFlags.WidthStretch)))) {
        unsafe { *p_flags = *p_flags & ~stretch_mask; }
    }
    if (edit_checkbox_flags(p_flags, (id = "CF_WF", text = "_WidthFixed",
        flags_value = int(ImGuiTableColumnFlags.WidthFixed)))) {
        unsafe { *p_flags = *p_flags & ~fixed_mask; }
    }
    edit_checkbox_flags(p_flags, (id = "CF_NR", text = "_NoResize",
        flags_value = int(ImGuiTableColumnFlags.NoResize)))
    edit_checkbox_flags(p_flags, (id = "CF_NRO", text = "_NoReorder",
        flags_value = int(ImGuiTableColumnFlags.NoReorder)))
    edit_checkbox_flags(p_flags, (id = "CF_NH", text = "_NoHide",
        flags_value = int(ImGuiTableColumnFlags.NoHide)))
    edit_checkbox_flags(p_flags, (id = "CF_NC", text = "_NoClip",
        flags_value = int(ImGuiTableColumnFlags.NoClip)))
    edit_checkbox_flags(p_flags, (id = "CF_NS", text = "_NoSort",
        flags_value = int(ImGuiTableColumnFlags.NoSort)))
    edit_checkbox_flags(p_flags, (id = "CF_NSA", text = "_NoSortAscending",
        flags_value = int(ImGuiTableColumnFlags.NoSortAscending)))
    edit_checkbox_flags(p_flags, (id = "CF_NSD", text = "_NoSortDescending",
        flags_value = int(ImGuiTableColumnFlags.NoSortDescending)))
    edit_checkbox_flags(p_flags, (id = "CF_NHL", text = "_NoHeaderLabel",
        flags_value = int(ImGuiTableColumnFlags.NoHeaderLabel)))
    edit_checkbox_flags(p_flags, (id = "CF_NHW", text = "_NoHeaderWidth",
        flags_value = int(ImGuiTableColumnFlags.NoHeaderWidth)))
    edit_checkbox_flags(p_flags, (id = "CF_PSA", text = "_PreferSortAscending",
        flags_value = int(ImGuiTableColumnFlags.PreferSortAscending)))
    edit_checkbox_flags(p_flags, (id = "CF_PSD", text = "_PreferSortDescending",
        flags_value = int(ImGuiTableColumnFlags.PreferSortDescending)))
    edit_checkbox_flags(p_flags, (id = "CF_IE", text = "_IndentEnable",
        flags_value = int(ImGuiTableColumnFlags.IndentEnable)))
    edit_checkbox_flags(p_flags, (id = "CF_ID", text = "_IndentDisable",
        flags_value = int(ImGuiTableColumnFlags.IndentDisable)))
    edit_checkbox_flags(p_flags, (id = "CF_AH", text = "_AngledHeader",
        flags_value = int(ImGuiTableColumnFlags.AngledHeader)))
}

// show_column_status_flags — read-only display of the status bits ImGui
// computes per frame (cpp `ShowTableColumnsStatusFlags`, cpp:4146-4152).
// Always called inside `with_disabled(true)` so the checkboxes paint but
// don't accept input.
def private show_column_status_flags(flags : int) {
    var local = flags
    edit_checkbox_flags(unsafe(addr(local)),
        (id = "CSF_IE", text = "_IsEnabled",
         flags_value = int(ImGuiTableColumnFlags.IsEnabled)))
    edit_checkbox_flags(unsafe(addr(local)),
        (id = "CSF_IV", text = "_IsVisible",
         flags_value = int(ImGuiTableColumnFlags.IsVisible)))
    edit_checkbox_flags(unsafe(addr(local)),
        (id = "CSF_IS", text = "_IsSorted",
         flags_value = int(ImGuiTableColumnFlags.IsSorted)))
    edit_checkbox_flags(unsafe(addr(local)),
        (id = "CSF_IH", text = "_IsHovered",
         flags_value = int(ImGuiTableColumnFlags.IsHovered)))
}

// =============================================================================
// Section 12: Columns widths — cpp:4938-5002
// =============================================================================
def private show_columns_widths() {
    apply_open_action()
    tree_node(TABLES_CW, (text = "Columns widths",
                          flags = ImGuiTreeNodeFlags.None)) {
        // ----- Sub-table 1: TableSetupColumn default-width form -----
        edit_checkbox_flags(safe_addr(TABLES_CW1_FLAGS),
            (id = "TBL_CW1_F_RESIZABLE", text = "ImGuiTableFlags_Resizable",
             flags_value = int(ImGuiTableFlags.Resizable)))
        edit_checkbox_flags(safe_addr(TABLES_CW1_FLAGS),
            (id = "TBL_CW1_F_NBINBODYUNTILRESIZE",
             text = "ImGuiTableFlags_NoBordersInBodyUntilResize",
             flags_value = int(ImGuiTableFlags.NoBordersInBodyUntilResize)))

        data_table(TABLES_CW1_T,
                   (text = "##cw_table1", columns = 3,
                    flags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_CW1_FLAGS)),
                    outer_size = float2(0.0f, 0.0f),
                    inner_width = 0.0f)) {
            // Could alternatively set _SizingFixedFit on the table.
            table_setup_column("one", ImGuiTableColumnFlags.WidthFixed, 100.0f)
            table_setup_column("two", ImGuiTableColumnFlags.WidthFixed, 200.0f)
            table_setup_column("three", ImGuiTableColumnFlags.WidthFixed)
            table_headers_row()
            for (row in range(4)) {
                table_next_row()
                for (col in range(3)) {
                    table_set_column_index(col)
                    let key = row * 3 + col
                    if (row == 0) {
                        let w = GetContentRegionAvail().x
                        text(TABLES_CW1_CELL[key], (text = "(w: {w})"))
                    } else {
                        text(TABLES_CW1_CELL[key],
                             (text = "Hello {col},{row}"))
                    }
                }
            }
        }

        // ----- Sub-table 2: explicit width per column (TEXT_BASE_WIDTH * N) -----
        edit_checkbox_flags(safe_addr(TABLES_CW2_FLAGS),
            (id = "TBL_CW2_F_NOKEEP", text = "ImGuiTableFlags_NoKeepColumnsVisible",
             flags_value = int(ImGuiTableFlags.NoKeepColumnsVisible)))
        edit_checkbox_flags(safe_addr(TABLES_CW2_FLAGS),
            (id = "TBL_CW2_F_BORDERS_IV", text = "ImGuiTableFlags_BordersInnerV",
             flags_value = int(ImGuiTableFlags.BordersInnerV)))
        edit_checkbox_flags(safe_addr(TABLES_CW2_FLAGS),
            (id = "TBL_CW2_F_BORDERS_OV", text = "ImGuiTableFlags_BordersOuterV",
             flags_value = int(ImGuiTableFlags.BordersOuterV)))

        let text_base_width = CalcTextSize("A").x
        data_table(TABLES_CW2_T,
                   (text = "##cw_table2", columns = 4,
                    flags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_CW2_FLAGS)),
                    outer_size = float2(0.0f, 0.0f),
                    inner_width = 0.0f)) {
            table_setup_column("", ImGuiTableColumnFlags.WidthFixed, 100.0f)
            table_setup_column("", ImGuiTableColumnFlags.WidthFixed,
                               text_base_width * 15.0f)
            table_setup_column("", ImGuiTableColumnFlags.WidthFixed,
                               text_base_width * 30.0f)
            table_setup_column("", ImGuiTableColumnFlags.WidthFixed,
                               text_base_width * 15.0f)
            for (row in range(5)) {
                table_next_row()
                for (col in range(4)) {
                    table_set_column_index(col)
                    let key = row * 4 + col
                    if (row == 0) {
                        let w = GetContentRegionAvail().x
                        text(TABLES_CW2_CELL[key], (text = "(w: {w})"))
                    } else {
                        text(TABLES_CW2_CELL[key],
                             (text = "Hello {col},{row}"))
                    }
                }
            }
        }
    }
}

// =============================================================================
// Section 13: Nested tables — cpp:5006-5047
// =============================================================================
def private show_nested_tables() {
    apply_open_action()
    tree_node(TABLES_NESTED, (text = "Nested tables",
                              flags = ImGuiTreeNodeFlags.None)) {
        let outer_flags = (ImGuiTableFlags.Borders | ImGuiTableFlags.Resizable |
                           ImGuiTableFlags.Reorderable | ImGuiTableFlags.Hideable)
        data_table(TABLES_NESTED_OUTER_T,
                   (text = "##nested_outer", columns = 2,
                    flags = outer_flags,
                    outer_size = float2(0.0f, 0.0f),
                    inner_width = 0.0f)) {
            table_setup_column("A0")
            table_setup_column("A1")
            table_headers_row()

            // Cell (0, 0): outer label + nested 2-col data_table.
            table_next_column()
            text(TABLES_NESTED_OUTER_CELL[0], (text = "A0 Row 0"))

            let rows_height = GetTextLineHeightWithSpacing() * 2.0f
            data_table(TABLES_NESTED_INNER_T,
                       (text = "##nested_inner", columns = 2,
                        flags = outer_flags,
                        outer_size = float2(0.0f, 0.0f),
                        inner_width = 0.0f)) {
                table_setup_column("B0")
                table_setup_column("B1")
                table_headers_row()

                table_next_row(ImGuiTableRowFlags.None, rows_height)
                table_next_column()
                text(TABLES_NESTED_INNER_CELL[0], (text = "B0 Row 0"))
                table_next_column()
                text(TABLES_NESTED_INNER_CELL[1], (text = "B1 Row 0"))
                table_next_row(ImGuiTableRowFlags.None, rows_height)
                table_next_column()
                text(TABLES_NESTED_INNER_CELL[2], (text = "B0 Row 1"))
                table_next_column()
                text(TABLES_NESTED_INNER_CELL[3], (text = "B1 Row 1"))
            }

            // Continue outer table after the nested one.
            table_next_column()
            text(TABLES_NESTED_OUTER_CELL[1], (text = "A1 Row 0"))
            table_next_column()
            text(TABLES_NESTED_OUTER_CELL[2], (text = "A0 Row 1"))
            table_next_column()
            text(TABLES_NESTED_OUTER_CELL[3], (text = "A1 Row 1"))
        }
    }
}

// =============================================================================
// Section 14: Row height — cpp:5052-5112
// =============================================================================
def private show_row_height() {
    apply_open_action()
    tree_node(TABLES_RH, (text = "Row height",
                          flags = ImGuiTreeNodeFlags.None)) {
        let line_height = GetTextLineHeightWithSpacing()

        // ----- Sub 1: min_row_height grows linearly per row -----
        data_table(TABLES_RH1_T,
                   (text = "##rh_table", columns = 1,
                    flags = ImGuiTableFlags.Borders,
                    outer_size = float2(0.0f, 0.0f),
                    inner_width = 0.0f)) {
            for (row in range(8)) {
                let min_row_height = float(int(line_height * 0.30f * float(row)))
                table_next_row(ImGuiTableRowFlags.None, min_row_height)
                table_next_column()
                text(TABLES_RH1_CELL[row],
                     (text = "min_row_height = {min_row_height}"))
            }
        }

        // ----- Sub 2: SameLine(0, 0) shares line height across cells -----
        // Two rows; each has a ColorButton in col 0 and a 2-line text in
        // col 1. Row 1 puts an explicit `SameLine(0, 0)` before the
        // first text line to demonstrate sharing the previous column's
        // line height.
        data_table(TABLES_RH2_T,
                   (text = "##rh_share", columns = 2,
                    flags = ImGuiTableFlags.Borders,
                    outer_size = float2(0.0f, 0.0f),
                    inner_width = 0.0f)) {
            let cb_color = float4(0.13f, 0.26f, 0.40f, 1.0f)
            let cb_size = float2(40.0f, 40.0f)

            table_next_row()
            table_next_column()
            color_button(TABLES_RH2_COLOR_BTN[0],
                         (desc_id = "##rh2_cb0", col = cb_color, size = cb_size,
                          flags = ImGuiColorEditFlags.None))
            table_next_column()
            text(TABLES_RH2_LINE1[0], (text = "Line 1"))
            text(TABLES_RH2_LINE2[0], (text = "Line 2"))

            table_next_row()
            table_next_column()
            color_button(TABLES_RH2_COLOR_BTN[1],
                         (desc_id = "##rh2_cb1", col = cb_color, size = cb_size,
                          flags = ImGuiColorEditFlags.None))
            table_next_column()
            // SameLine(0, 0) reuses line height from previous column.
            same_line(TABLES_RH2_SL_REUSE,
                      (offset_from_start_x = 0.0f, spacing = 0.0f))
            text(TABLES_RH2_LINE1[1], (text = "Line 1, with SameLine(0,0)"))
            text(TABLES_RH2_LINE2[1], (text = "Line 2"))
        }

        // ----- Sub 3: per-row CellPadding.y mutation (every 3rd row) -----
        // cpp uses raw `Push/PopStyleVar(CellPadding)` only on rows where
        // `row % 3 == 2`. The boost `with_style(...)` block scopes the
        // push to its body, so we wrap just the row-2 emit in it.
        data_table(TABLES_RH3_T,
                   (text = "##rh_cellpad_y", columns = 1,
                    flags = ImGuiTableFlags.Borders,
                    outer_size = float2(0.0f, 0.0f),
                    inner_width = 0.0f)) {
            let cell_padding_x = GetStyle().CellPadding.x
            let cell_padding_y = GetStyle().CellPadding.y
            for (row in range(8)) {
                if (row % 3 == 2) {
                    with_style((ImGuiStyleVar.CellPadding,
                                float2(cell_padding_x, 20.0f))) {
                        table_next_row(ImGuiTableRowFlags.None)
                        table_next_column()
                        text(TABLES_RH3_CELL[row],
                             (text = "CellPadding.y = {cell_padding_y}"))
                    }
                } else {
                    table_next_row(ImGuiTableRowFlags.None)
                    table_next_column()
                    text(TABLES_RH3_CELL[row],
                         (text = "CellPadding.y = {cell_padding_y}"))
                }
            }
        }
    }
}

// =============================================================================
// Section 15: Outer size — cpp:5117-5179
// =============================================================================
def private show_outer_size() {
    apply_open_action()
    tree_node(TABLES_OS, (text = "Outer size",
                          flags = ImGuiTreeNodeFlags.None)) {
        text(TABLES_OS_HEADER_TEXT, (text = "Using NoHostExtendX and NoHostExtendY:"))

        edit_checkbox_flags(safe_addr(TABLES_OS1_FLAGS),
            (id = "TBL_OS1_F_NOHOSTX", text = "ImGuiTableFlags_NoHostExtendX",
             flags_value = int(ImGuiTableFlags.NoHostExtendX)))
        edit_checkbox_flags(safe_addr(TABLES_OS1_FLAGS),
            (id = "TBL_OS1_F_NOHOSTY", text = "ImGuiTableFlags_NoHostExtendY",
             flags_value = int(ImGuiTableFlags.NoHostExtendY)))

        let line_height = GetTextLineHeightWithSpacing()
        let outer_size_1 = float2(0.0f, line_height * 5.5f)
        data_table(TABLES_OS1_T,
                   (text = "##os_table1", columns = 3,
                    flags = unsafe(reinterpret<ImGuiTableFlags>(TABLES_OS1_FLAGS)),
                    outer_size = outer_size_1,
                    inner_width = 0.0f)) {
            for (row in range(10)) {
                table_next_row()
                for (col in range(3)) {
                    table_next_column()
                    text(TABLES_OS1_CELL[row * 3 + col],
                         (text = "Cell {col},{row}"))
                }
            }
        }
        same_line(TABLES_OS1_SL)
        text(TABLES_OS1_HELLO, (text = "Hello!"))

        spacing()
        text(TABLES_OS_EXPLICIT_HEADER, (text = "Using explicit size:"))

        let text_base_width = CalcTextSize("A").x
        let explicit_size = float2(text_base_width * 30.0f, 0.0f)
        let table_2_3_flags = (ImGuiTableFlags.Borders | ImGuiTableFlags.RowBg)

        data_table(TABLES_OS2_T,
                   (text = "##os_table2", columns = 3,
                    flags = table_2_3_flags,
                    outer_size = explicit_size,
                    inner_width = 0.0f)) {
            for (row in range(5)) {
                table_next_row()
                for (col in range(3)) {
                    table_next_column()
                    text(TABLES_OS2_CELL[row * 3 + col],
                         (text = "Cell {col},{row}"))
                }
            }
        }
        same_line(TABLES_OS_SL_2_3)
        data_table(TABLES_OS3_T,
                   (text = "##os_table3", columns = 3,
                    flags = table_2_3_flags,
                    outer_size = explicit_size,
                    inner_width = 0.0f)) {
            for (row in range(3)) {
                table_next_row(ImGuiTableRowFlags.None, line_height * 1.5f)
                for (col in range(3)) {
                    table_next_column()
                    text(TABLES_OS3_CELL[row * 3 + col],
                         (text = "Cell {col},{row}"))
                }
            }
        }
    }
}
