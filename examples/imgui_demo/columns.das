options gen2
options indenting = 4

module columns

require imgui
require imgui/imgui_widgets_builtin
require imgui/imgui_containers_builtin
require imgui/imgui_layout_builtin
require imgui/imgui_scope_builtin
require daslib/safe_addr

// =============================================================================
// Mirrors imgui_demo.cpp:6045-6248 — static void ShowDemoWindowColumns().
//
// Boost-surface conventions for this port:
//   - The legacy Columns() API is exposed via two boost rails:
//       * `columns(N, { col1 }, { col2 }, ..., { colN })` — the call_macro form;
//         requires a literal column count and exactly N block args. Used for
//         the static-shape sub-sections (Mixed items, Word-wrapping).
//       * `columns_open(N)` / `next_col()` / `columns_close()` — the raw
//         primitive trio used by the macro itself; we call them directly when
//         the column structure is dynamic (Basic's two loops, Borders with a
//         user-driven count, Horizontal Scrolling's clipper, Tree's nested
//         iteration).
//   - Per-section TreeNode'd sub-sections use boost `tree_node(IDENT, ...)`.
//   - In-loop click and tree state goes through indexed widget tables
//     (`IDENT[k]`) declared at module scope.
//   - The C++ `HelpMarker(...)` call after the outer TreeNode title is
//     reproduced inline as `same_line` + `text_disabled("(?)")` +
//     `item_tooltip { text_unformatted(...) }`.
//   - Skipped vs C++ (cited in the relevant block):
//       * The "Basic" second table's `static int selected = -1` single-select
//         radio-style behaviour is approximated with per-row independent
//         `selectable` toggles — the boost selectable owns its own bool and
//         we keep the demo focused on columns, not selection model. See note
//         at PortSecondBasicTable.
//       * The "Horizontal Scrolling" sub-section uses `ImGuiListClipper`, which
//         the daslang binding exposes as a constructed object with Begin/Step/
//         End methods. We use the binding directly inside the
//         `child(...) { ... }` container.
// =============================================================================

// ----- Sub-section TreeNodes (outer + 6 sub-sections) -----
// All `tree_node(IDENT, ...)` macros auto-emit one TreeNodeState global per
// IDENT — these are referenced implicitly by the macro, no `var` declarations
// needed at module scope.

// ----- App-state plain vars -----
// The Borders sub-section flips these via boost edit_* widgets against
// module-scope vars. `var` (not widget-managed) keeps the value addressable
// for `safe_addr`.
var COLUMNS_BORDERS_H = true
var COLUMNS_BORDERS_V = true
var COLUMNS_BORDERS_COUNT = 4

// Mixed items sub-section — two float values edited by boost edit_input_float.
var COLUMNS_MIXED_FOO = 1.0f
var COLUMNS_MIXED_BAR = 1.0f

// ----- Indexed widget tables (declared upfront — the [widget] macro does
//       NOT auto-emit table<K; ST> globals for indexed-ident forms) -----
var private COLUMNS_BASIC_SEL1 : table<int; ToggleState>
var private COLUMNS_BASIC_SEL2 : table<int; ToggleState>
var private COLUMNS_TREE_OUTER : table<int; TreeNodeState>
var private COLUMNS_TREE_INNER : table<int; TreeNodeState>

// =============================================================================
// ShowDemoWindowColumns — outer dispatcher
// =============================================================================
def ShowDemoWindowColumns() {
    tree_node(COLUMNS_OUTER,
        (text = "Legacy Columns API", flags = ImGuiTreeNodeFlags.None)) {
        SameLine()
        text_disabled("(?)")
        item_tooltip(COLUMNS_OUTER_HELP) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text =
                    "Columns() is an old API! Prefer using the more flexible " +
                    "and powerful BeginTable() API!"))
            }
        }

        BasicSection()
        BordersSection()
        MixedItemsSection()
        WordWrappingSection()
        HorizontalScrollingSection()
        TreeSection()
    }
}

// =============================================================================
// Basic — cpp:6055-6098
// =============================================================================
def private BasicSection() {
    tree_node(COLUMNS_BASIC, (text = "Basic", flags = ImGuiTreeNodeFlags.None)) {
        text("Without border:")
        // 3-way, no border. Dynamic 14-item loop ⇒ call columns_open/next_col
        // directly (the columns(N, ...) macro requires N literal blocks).
        Columns(3, "mycolumns3", false)
        Separator()
        for (n in range(14)) {
            selectable(COLUMNS_BASIC_SEL1[n], (text = "Item {n}"))
            NextColumn()
        }
        columns_close()
        Separator()

        text("With border:")
        // 4-way, with border. Header row + 3 data rows; structure is regular
        // but still loop-driven on row count.
        Columns(4, "mycolumns", true)
        Separator()
        text("ID"); NextColumn()
        text("Name"); NextColumn()
        text("Path"); NextColumn()
        text("Hovered"); NextColumn()
        Separator()
        let names = fixed_array("One", "Two", "Three")
        let paths = fixed_array("/path/one", "/path/two", "/path/three")
        for (i in range(3)) {
            // Per-row independent toggle (see file header — single-select
            // C++ semantics deliberately not preserved). SpanAllColumns flag
            // makes the row's selectable cover all four columns.
            selectable(COLUMNS_BASIC_SEL2[i],
                (text = "{i}",
                 flags = ImGuiSelectableFlags.SpanAllColumns))
            let hovered = IsItemHovered()
            NextColumn()
            text((text = "{names[i]}")); NextColumn()
            text((text = "{paths[i]}")); NextColumn()
            text((text = "{hovered ? 1 : 0}")); NextColumn()
        }
        columns_close()
        Separator()
    }
}

// =============================================================================
// Borders — cpp:6100-6133
// =============================================================================
def private BordersSection() {
    tree_node(COLUMNS_BORDERS, (text = "Borders", flags = ImGuiTreeNodeFlags.None)) {
        let lines_count = 3
        SetNextItemWidth(GetFontSize() * 8.0f)
        edit_drag_int(safe_addr(COLUMNS_BORDERS_COUNT),
            (id = "COLUMNS_BORDERS_COUNT", text = "##columns_count",
             speed = 0.1f, v_min = 2, v_max = 10, format = "%d columns"))
        if (COLUMNS_BORDERS_COUNT < 2) {
            COLUMNS_BORDERS_COUNT = 2
        }
        SameLine()
        edit_checkbox(safe_addr(COLUMNS_BORDERS_H),
            (id = "COLUMNS_BORDERS_H", text = "horizontal"))
        SameLine()
        edit_checkbox(safe_addr(COLUMNS_BORDERS_V),
            (id = "COLUMNS_BORDERS_V", text = "vertical"))
        // Dynamic column count ⇒ raw Columns() call.
        Columns(COLUMNS_BORDERS_COUNT, "", COLUMNS_BORDERS_V)
        for (i in range(COLUMNS_BORDERS_COUNT * lines_count)) {
            if (COLUMNS_BORDERS_H && GetColumnIndex() == 0) {
                Separator()
            }
            // C++ uses ImGui::Text("%c%c%c", 'a' + i, ...); daslang has no
            // int→char primitive — splice via a precomputed alphabet table.
            let alphabet = fixed_array(
                "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
                "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
                "u", "v", "w", "x", "y", "z", "0", "1", "2", "3")
            let glyph = alphabet[i % length(alphabet)]
            text((text = "{glyph}{glyph}{glyph}"))
            text((text = "Width {GetColumnWidth(-1)}"))
            text((text = "Avail {GetContentRegionAvail().x}"))
            text((text = "Offset {GetColumnOffset(-1)}"))
            text("Long text that is likely to clip")
            // Per-cell button — indexed; full-width via Button raw call so we
            // can pass ImVec2(-FLT_MIN, 0). The boost button widget defaults
            // size to (0,0).
            if (Button("Button##{i}", ImVec2(-3.40282347e+38f, 0.0f))) {}
            NextColumn()
        }
        columns_close()
        if (COLUMNS_BORDERS_H) {
            Separator()
        }
    }
}

// =============================================================================
// Mixed items — cpp:6136-6165
// =============================================================================
def private MixedItemsSection() {
    tree_node(COLUMNS_MIXED, (text = "Mixed items", flags = ImGuiTreeNodeFlags.None)) {
        columns(3, ${
            Separator()
            text("Hello")
            button(COLUMNS_MIXED_BTN_BANANA, (text = "Banana"))
        }, ${
            text("ImGui")
            button(COLUMNS_MIXED_BTN_APPLE, (text = "Apple"))
            edit_input_float(safe_addr(COLUMNS_MIXED_FOO),
                (id = "COLUMNS_MIXED_FOO", text = "red",
                 step = 0.05f, step_fast = 0.0f, format = "%.3f"))
            text("An extra line here.")
        }, ${
            text("Sailor")
            button(COLUMNS_MIXED_BTN_CORN, (text = "Corniflower"))
            edit_input_float(safe_addr(COLUMNS_MIXED_BAR),
                (id = "COLUMNS_MIXED_BAR", text = "blue",
                 step = 0.05f, step_fast = 0.0f, format = "%.3f"))
        })
        // Second 3-column row: three CollapsingHeader cells. Each header
        // is independent state, so we want three separate columns blocks
        // executed in sequence — but the columns macro also closes the
        // columns block between calls, which is exactly the C++ pattern of
        // "open columns, render a row, close" except C++ stays open across
        // two rows. Here we keep one columns() per row.
        columns(3, ${
            collapsing_header(COLUMNS_MIXED_CHA,
                (text = "Category A", closable = false,
                 flags = ImGuiTreeNodeFlags.None)) {
                text("Blah blah blah")
            }
        }, ${
            collapsing_header(COLUMNS_MIXED_CHB,
                (text = "Category B", closable = false,
                 flags = ImGuiTreeNodeFlags.None)) {
                text("Blah blah blah")
            }
        }, ${
            collapsing_header(COLUMNS_MIXED_CHC,
                (text = "Category C", closable = false,
                 flags = ImGuiTreeNodeFlags.None)) {
                text("Blah blah blah")
            }
        })
        Separator()
    }
}

// =============================================================================
// Word-wrapping — cpp:6168-6181
// =============================================================================
def private WordWrappingSection() {
    tree_node(COLUMNS_WRAP, (text = "Word-wrapping", flags = ImGuiTreeNodeFlags.None)) {
        columns(2, ${
            Separator()
            text_wrapped(COLUMNS_WRAP_TXT_L1,
                (text = "The quick brown fox jumps over the lazy dog."))
            text_wrapped(COLUMNS_WRAP_TXT_L2, (text = "Hello Left"))
        }, ${
            text_wrapped(COLUMNS_WRAP_TXT_R1,
                (text = "The quick brown fox jumps over the lazy dog."))
            text_wrapped(COLUMNS_WRAP_TXT_R2, (text = "Hello Right"))
        })
        Separator()
    }
}

// =============================================================================
// Horizontal Scrolling — cpp:6183-6207
// =============================================================================
def private HorizontalScrollingSection() {
    tree_node(COLUMNS_HSCROLL,
        (text = "Horizontal Scrolling", flags = ImGuiTreeNodeFlags.None)) {
        SetNextWindowContentSize(ImVec2(1500.0f, 0.0f))
        let child_size = float2(0.0f, GetFontSize() * 20.0f)
        child(COLUMNS_HSCROLL_CHILD,
            (text = "##ScrollingRegion", size = child_size,
             child_flags = ImGuiChildFlags.None,
             window_flags = ImGuiWindowFlags.HorizontalScrollbar)) {
            Columns(10, "", true)
            // ImGuiListClipper culls the 2000 virtual rows down to the visible
            // window — same pattern as the C++ demo. The class has a default
            // ctor on the C++ side; require `unsafe` because the binding
            // doesn't mark the type safe-to-construct.
            unsafe {
                var clipper = ImGuiListClipper()
                clipper |> Begin(2000, -1.0f)
                while (clipper |> Step()) {
                    for (i in range(clipper.DisplayStart, clipper.DisplayEnd)) {
                        for (j in range(10)) {
                            text((text = "Line {i} Column {j}..."))
                            NextColumn()
                        }
                    }
                }
                clipper |> End()
            }
            columns_close()
        }
    }
}

// =============================================================================
// Tree — cpp:6209-6244
// =============================================================================
def private TreeSection() {
    tree_node(COLUMNS_TREE, (text = "Tree", flags = ImGuiTreeNodeFlags.None)) {
        Columns(2, "tree", true)
        for (x in range(3)) {
            tree_node(COLUMNS_TREE_OUTER[x],
                (text = "Node{x}", flags = ImGuiTreeNodeFlags.None)) {
                NextColumn()
                text("Node contents")
                NextColumn()
                for (y in range(3)) {
                    let inner_key = x * 10 + y
                    tree_node(COLUMNS_TREE_INNER[inner_key],
                        (text = "Node{x}.{y}", flags = ImGuiTreeNodeFlags.None)) {
                        NextColumn()
                        text("Node contents")
                        text("Even more contents")
                        tree_node(COLUMNS_TREE_LEAF,
                            (text = "Tree in column", flags = ImGuiTreeNodeFlags.None)) {
                            text("The quick brown fox jumps over the lazy dog")
                        }
                        NextColumn()
                    }
                    if (!COLUMNS_TREE_INNER[inner_key].opened) {
                        // The outer NextColumn pair is owned by the open
                        // branch in C++ (gated by `if (open2)`). Mirror that:
                        // when the inner tree was NOT expanded, the outer
                        // already advanced once for the title; we still need
                        // to fill the body column.
                        NextColumn()
                        text("Node contents")
                        NextColumn()
                    }
                }
            }
            // C++ structure: the outer NextColumns inside the open-branch
            // already advanced when expanded. When the outer tree was NOT
            // expanded, we still need to skip past its two columns to land
            // on the next row.
            if (!COLUMNS_TREE_OUTER[x].opened) {
                NextColumn()
                NextColumn()
            }
        }
        columns_close()
    }
}
