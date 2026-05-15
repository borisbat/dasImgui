options gen2
options indenting = 4
options _allow_imgui_legacy = true

module layout

require imgui
require imgui/imgui_widgets_builtin
require imgui/imgui_containers_builtin
require imgui/imgui_id_builtin
require imgui/imgui_scope_builtin
require imgui/imgui_layout_builtin
require imgui/imgui_style_builtin
require daslib/safe_addr
require app_main_menu
require math

// =============================================================================
// Mirrors imgui_demo.cpp:2836-3694 — static void ShowDemoWindowLayout().
//
// Boost-surface conventions (same as widgets.das / style_editor.das):
//   - Narrative widgets (text/separator_text/bullet_text/spacing/new_line/dummy)
//     go through the no-ident form in imgui_widgets_builtin.
//   - Interactive widgets (checkbox/drag_int/drag_float/slider_int/combo/
//     selectable) go through [widget] with an IDENT first arg + named args.
//   - Containers (child/tree_node/tab_bar/tab_item/group/item_tooltip/list_box)
//     replace raw Begin/End pairs.
//   - Push/Pop wrappers — with_id / with_item_width / with_clip_rect /
//     with_button_repeat / with_style / with_indent — replace raw Push/Pop.
//   - Sized buttons (ImVec2 size argument) stay raw `Button(label, size)`
//     because the v2 [widget] button is fixed-size only (no size param).
//   - IMGUI_DEMO_MARKER lines dropped (off-limits per CLAUDE.md).
//   - HelpMarker(...) text inlined via item_tooltip on a "(?)" text_disabled,
//     mirroring widgets.das.
//
// Skipped vs C++ (each cited at the relevant location below):
//   - cpp:3604: DragFloat2 on a `ImVec2 size` (struct field-pair). The
//     edit_drag_float2 rail wants a `float2?`, and ImVec2's float-pair layout
//     matches float2's, but addressing a stack ImVec2 as float2? would need
//     a reinterpret bounce-buffer. Workaround: edit two separate floats.
//   - cpp:3631-3656: the per-clip-region DrawList calls — AddRectFilled /
//     AddText to the WindowDrawList. These need draw-list pointer plumbing
//     that isn't on the boost surface yet; the three clipping regions render
//     as InvisibleButton-only stubs. TODO Phase 3.
// =============================================================================

// ----- Child windows section -----
var LAYOUT_CHILD_DISABLE_MOUSE_WHEEL = false
var LAYOUT_CHILD_DISABLE_MENU = false
var LAYOUT_CHILD_OFFSET_X = 0
var LAYOUT_CHILD_OVERRIDE_BG = true
var LAYOUT_CHILD_FLAGS = (int(ImGuiChildFlags.Border) |
                          int(ImGuiChildFlags.ResizeX) |
                          int(ImGuiChildFlags.ResizeY))

// ----- Widgets Width -----
var LAYOUT_WW_FLOAT = 0.0f
var LAYOUT_WW_SHOW_INDENTED = true

// ----- Basic Horizontal Layout -----
var LAYOUT_BHL_C1 = false
var LAYOUT_BHL_C2 = false
var LAYOUT_BHL_C3 = false
var LAYOUT_BHL_C4 = false
var LAYOUT_BHL_F0 = 1.0f
var LAYOUT_BHL_F1 = 2.0f
var LAYOUT_BHL_F2 = 3.0f
var LAYOUT_BHL_COMBO_ITEM = -1
var LAYOUT_BHL_SELECTION = [0, 1, 2, 3]

// ----- Scrolling -----
var LAYOUT_SCROLL_TRACK_ITEM = 50
var LAYOUT_SCROLL_ENABLE_TRACK = true
var LAYOUT_SCROLL_ENABLE_EXTRA_DECOR = false
var LAYOUT_SCROLL_TO_OFF_PX = 0.0f
var LAYOUT_SCROLL_TO_POS_PX = 200.0f
var LAYOUT_SCROLL_HORIZ_LINES = 7
var LAYOUT_SCROLL_SHOW_HSZ_DEMO = false

// ----- Horizontal contents-size demo window -----
var LAYOUT_HSZ_SHOW_HSCROLL = true
var LAYOUT_HSZ_SHOW_BUTTON = true
var LAYOUT_HSZ_SHOW_TREE_NODES = true
var LAYOUT_HSZ_SHOW_TEXT_WRAPPED = false
var LAYOUT_HSZ_SHOW_COLUMNS = true
var LAYOUT_HSZ_SHOW_TAB_BAR = true
var LAYOUT_HSZ_SHOW_CHILD = false
var LAYOUT_HSZ_EXPLICIT_CONTENT_SIZE = false
var LAYOUT_HSZ_CONTENTS_SIZE_X = 300.0f

// ----- Text Clipping -----
var LAYOUT_CLIP_SIZE = float2(100.0f, 100.0f)
var LAYOUT_CLIP_OFFSET = float2(30.0f, 30.0f)

// ----- Overlap Mode -----
var LAYOUT_OVERLAP_ENABLE = true

// ----- Indexed widget tables -----
// Per-loop-index state globals. [widget] indexed form requires the backing
// table at module scope (the macro doesn't auto-emit indexed tables).
var private LAYOUT_VS_GROUP : table<int; GroupState>
var private LAYOUT_VS_CHILD : table<int; ChildState>
var private LAYOUT_HS_CHILD : table<int; ChildState>
var private LAYOUT_HS_SL : table<int; EmptyMarkerState>
var private LAYOUT_HS_LABEL : table<int; NarrativeState>
var private LAYOUT_LBOX : table<int; ListBoxState>
var private LAYOUT_LBOX_SL : table<int; EmptyMarkerState>
var private LAYOUT_LBOX_ITEM : table<int; ToggleState>
// Misc inline narrative/marker state for loops
var private LAYOUT_LOOP_SL_HS : table<int; EmptyMarkerState>
var private LAYOUT_LOOP_TEXT_VS : table<int; NarrativeState>
var private LAYOUT_LOOP_SL_CLIP : table<int; EmptyMarkerState>
var private LAYOUT_TBA_NODE1_BT : table<int; NarrativeState>
var private LAYOUT_TBA_NODE2_BT : table<int; NarrativeState>
var private LAYOUT_CLIP_BTN : table<int; ClickState>


// =============================================================================
// ShowDemoWindowLayout — dispatcher
// =============================================================================

def ShowDemoWindowLayout() {
    if (!CollapsingHeader("Layout & Scrolling")) return

    ChildWindowsSection()
    WidgetsWidthSection()
    BasicHorizontalLayoutSection()
    GroupsSection()
    TextBaselineAlignmentSection()
    ScrollingSection()
    TextClippingSection()
    OverlapModeSection()
    TabsSection()
}


// =============================================================================
// Child windows — cpp:2842-2971
// =============================================================================

def private ChildWindowsSection() {
    tree_node(LAYOUT_CHILD_TN, (text = "Child windows",
                                flags = ImGuiTreeNodeFlags.None)) {
        separator_text("Child windows")

        text("(?)")
        item_tooltip(LAYOUT_CHILD_HM1) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "Use child windows to begin into a self-contained " +
                    "independent scrolling/clipping regions within a host window."))
            }
        }
        edit_checkbox(safe_addr(LAYOUT_CHILD_DISABLE_MOUSE_WHEEL),
            (id = "LAYOUT_CHILD_DMW", text = "Disable Mouse Wheel"))
        edit_checkbox(safe_addr(LAYOUT_CHILD_DISABLE_MENU),
            (id = "LAYOUT_CHILD_DM", text = "Disable Menu"))

        // Child 1: no border, enable horizontal scrollbar.
        var win_flags_1 = int(ImGuiWindowFlags.HorizontalScrollbar)
        if (LAYOUT_CHILD_DISABLE_MOUSE_WHEEL) {
            win_flags_1 |= int(ImGuiWindowFlags.NoScrollWithMouse)
        }
        child(LAYOUT_CHILD_L,
              (text = "ChildL",
               size = float2(GetContentRegionAvail().x * 0.5f, 260.0f),
               child_flags = ImGuiChildFlags.None,
               window_flags = unsafe(reinterpret<ImGuiWindowFlags>(win_flags_1)))) {
            for (i in range(100)) {
                text("{i}: scrollable region")
            }
        }

        SameLine()

        // Child 2: rounded border, table of 100 buttons.
        var win_flags_2 = int(ImGuiWindowFlags.None)
        if (LAYOUT_CHILD_DISABLE_MOUSE_WHEEL) {
            win_flags_2 |= int(ImGuiWindowFlags.NoScrollWithMouse)
        }
        if (!LAYOUT_CHILD_DISABLE_MENU) {
            win_flags_2 |= int(ImGuiWindowFlags.MenuBar)
        }
        with_style((ImGuiStyleVar.ChildRounding, 5.0f)) {
            child(LAYOUT_CHILD_R,
                  (text = "ChildR", size = float2(0.0f, 260.0f),
                   child_flags = ImGuiChildFlags.Border,
                   window_flags = unsafe(reinterpret<ImGuiWindowFlags>(win_flags_2)))) {
                if (!LAYOUT_CHILD_DISABLE_MENU && BeginMenuBar()) {
                    if (BeginMenu("Menu", true)) {
                        ShowExampleMenuFile()
                        EndMenu()
                    }
                    EndMenuBar()
                }
                let table_flags = (int(ImGuiTableFlags.Resizable) |
                                   int(ImGuiTableFlags.NoSavedSettings))
                if (BeginTable("split", 2,
                               unsafe(reinterpret<ImGuiTableFlags>(table_flags)),
                               float2(0.0f, 0.0f), 0.0f)) {
                    for (i in range(100)) {
                        TableNextColumn()
                        Button("{fmt_3d(i)}", ImVec2(-FLT_MIN, 0.0f))
                    }
                    EndTable()
                }
            }
        }

        // Child 3: manual-resize (drag bottom border).
        separator_text("Manual-resize")
        text("(?)")
        item_tooltip(LAYOUT_CHILD_HM2) {
            text_unformatted((text = "Drag bottom border to resize. Double-click bottom border " +
                "to auto-fit to vertical contents."))
        }
        with_style((ImGuiCol.ChildBg, GetStyleColorVec4(ImGuiCol.FrameBg))) {
            let flags3 = int(ImGuiChildFlags.Border) | int(ImGuiChildFlags.ResizeY)
            child(LAYOUT_CHILD_RESIZABLE,
                  (text = "ResizableChild",
                   size = float2(-FLT_MIN, GetTextLineHeightWithSpacing() * 8.0f),
                   child_flags = unsafe(reinterpret<ImGuiChildFlags>(flags3)),
                   window_flags = ImGuiWindowFlags.None)) {
                for (n in range(10)) {
                    text("Line {fmt_4d(n)}")
                }
            }
        }

        // Child 4: auto-resizing height with a limit. Uses edit_drag_int.
        separator_text("Auto-resize with constraints")
        SetNextItemWidth(GetFontSize() * 8.0f)
        edit_drag_int(safe_addr(LAYOUT_CHILD_DRAW_LINES),
            (id = "LAYOUT_CHILD_DRAW_LINES", text = "Lines Count",
             speed = 0.2f))
        SetNextItemWidth(GetFontSize() * 8.0f)
        edit_drag_int(safe_addr(LAYOUT_CHILD_MAX_LINES),
            (id = "LAYOUT_CHILD_MAX_LINES", text = "Max Height (in Lines)",
             speed = 0.2f))
        SetNextWindowSizeConstraints(
            ImVec2(0.0f, GetTextLineHeightWithSpacing() * 1.0f),
            ImVec2(FLT_MAX,
                   GetTextLineHeightWithSpacing() * float(LAYOUT_CHILD_MAX_LINES)))
        let flags4 = int(ImGuiChildFlags.Border) | int(ImGuiChildFlags.AutoResizeY)
        child(LAYOUT_CHILD_CONSTRAINED,
              (text = "ConstrainedChild",
               size = float2(-FLT_MIN, 0.0f),
               child_flags = unsafe(reinterpret<ImGuiChildFlags>(flags4)),
               window_flags = ImGuiWindowFlags.None)) {
            for (n in range(LAYOUT_CHILD_DRAW_LINES)) {
                text("Line {fmt_4d(n)}")
            }
        }

        // Misc/Advanced — flags + offset + override-bg.
        separator_text("Misc/Advanced")
        SetNextItemWidth(GetFontSize() * 8.0f)
        edit_drag_int(safe_addr(LAYOUT_CHILD_OFFSET_X),
            (id = "LAYOUT_CHILD_OFFSET_X", text = "Offset X",
             speed = 1.0f, v_min = -1000, v_max = 1000))
        edit_checkbox(safe_addr(LAYOUT_CHILD_OVERRIDE_BG),
            (id = "LAYOUT_CHILD_OVERRIDE_BG", text = "Override ChildBg color"))
        edit_checkbox_flags(safe_addr(LAYOUT_CHILD_FLAGS),
            (id = "LAYOUT_CHILD_F_BORDER", text = "ImGuiChildFlags_Border",
             flags_value = int(ImGuiChildFlags.Border)))
        edit_checkbox_flags(safe_addr(LAYOUT_CHILD_FLAGS),
            (id = "LAYOUT_CHILD_F_AUWP", text = "ImGuiChildFlags_AlwaysUseWindowPadding",
             flags_value = int(ImGuiChildFlags.AlwaysUseWindowPadding)))
        edit_checkbox_flags(safe_addr(LAYOUT_CHILD_FLAGS),
            (id = "LAYOUT_CHILD_F_RX", text = "ImGuiChildFlags_ResizeX",
             flags_value = int(ImGuiChildFlags.ResizeX)))
        edit_checkbox_flags(safe_addr(LAYOUT_CHILD_FLAGS),
            (id = "LAYOUT_CHILD_F_RY", text = "ImGuiChildFlags_ResizeY",
             flags_value = int(ImGuiChildFlags.ResizeY)))
        edit_checkbox_flags(safe_addr(LAYOUT_CHILD_FLAGS),
            (id = "LAYOUT_CHILD_F_FS", text = "ImGuiChildFlags_FrameStyle",
             flags_value = int(ImGuiChildFlags.FrameStyle)))
        SameLine()
        text("(?)")
        item_tooltip(LAYOUT_CHILD_HM3) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "Style the child window like a framed item: use FrameBg, " +
                    "FrameRounding, FrameBorderSize, FramePadding instead of " +
                    "ChildBg, ChildRounding, ChildBorderSize, WindowPadding."))
            }
        }
        if ((LAYOUT_CHILD_FLAGS & int(ImGuiChildFlags.FrameStyle)) != 0) {
            LAYOUT_CHILD_OVERRIDE_BG = false
        }
        SetCursorPosX(GetCursorPosX() + float(LAYOUT_CHILD_OFFSET_X))
        if (LAYOUT_CHILD_OVERRIDE_BG) {
            PushStyleColor(ImGuiCol.ChildBg, 0x64_00_00_FFu)
        }
        child(LAYOUT_CHILD_RED,
              (text = "Red", size = float2(200.0f, 100.0f),
               child_flags = unsafe(reinterpret<ImGuiChildFlags>(LAYOUT_CHILD_FLAGS)),
               window_flags = ImGuiWindowFlags.None)) {
            for (n in range(50)) {
                text("Some test {n}")
            }
        }
        if (LAYOUT_CHILD_OVERRIDE_BG) {
            PopStyleColor(1)
        }
        let child_is_hovered = IsItemHovered(ImGuiHoveredFlags.None)
        let r_min = GetItemRectMin()
        let r_max = GetItemRectMax()
        text("Hovered: {child_is_hovered}")
        text((text = "Rect of child window is: ({r_min.x},{r_min.y}) " +
                     "({r_max.x},{r_max.y})"))
    }
}

// Stub holders so edit_drag_int can take safe_addr on them.
var LAYOUT_CHILD_DRAW_LINES = 3
var LAYOUT_CHILD_MAX_LINES = 10


// =============================================================================
// Widgets Width — cpp:2974-3048
// =============================================================================

def private WidgetsWidthSection() {
    tree_node(LAYOUT_WW_TN, (text = "Widgets Width",
                              flags = ImGuiTreeNodeFlags.None)) {
        edit_checkbox(safe_addr(LAYOUT_WW_SHOW_INDENTED),
            (id = "LAYOUT_WW_SI", text = "Show indented items"))

        // SetNextItemWidth/PushItemWidth(100)
        text("SetNextItemWidth/PushItemWidth(100)")
        SameLine()
        text_disabled("(?)")
        item_tooltip(LAYOUT_WW_HM1) {
            text_unformatted("Fixed width.")
        }
        with_item_width(100.0f) {
            edit_drag_float(safe_addr(LAYOUT_WW_FLOAT),
                (id = "LAYOUT_WW_F1B", text = "float##1b", speed = 1.0f))
            if (LAYOUT_WW_SHOW_INDENTED) {
                with_indent(0.0f) {
                    edit_drag_float(safe_addr(LAYOUT_WW_FLOAT),
                        (id = "LAYOUT_WW_F1BI",
                         text = "float (indented)##1b", speed = 1.0f))
                }
            }
        }

        // PushItemWidth(-100)
        text("SetNextItemWidth/PushItemWidth(-100)")
        SameLine()
        text_disabled("(?)")
        item_tooltip(LAYOUT_WW_HM2) {
            text_unformatted("Align to right edge minus 100")
        }
        with_item_width(-100.0f) {
            edit_drag_float(safe_addr(LAYOUT_WW_FLOAT),
                (id = "LAYOUT_WW_F2A", text = "float##2a", speed = 1.0f))
            if (LAYOUT_WW_SHOW_INDENTED) {
                with_indent(0.0f) {
                    edit_drag_float(safe_addr(LAYOUT_WW_FLOAT),
                        (id = "LAYOUT_WW_F2BI",
                         text = "float (indented)##2b", speed = 1.0f))
                }
            }
        }

        // PushItemWidth(GetContentRegionAvail().x * 0.5f)
        text("SetNextItemWidth/PushItemWidth(GetContentRegionAvail().x * 0.5f)")
        SameLine()
        text_disabled("(?)")
        item_tooltip(LAYOUT_WW_HM3) {
            text_unformatted((text = "Half of available width.\n(~ right-cursor_pos)\n" +
                "(works within a column set)"))
        }
        with_item_width(GetContentRegionAvail().x * 0.5f) {
            edit_drag_float(safe_addr(LAYOUT_WW_FLOAT),
                (id = "LAYOUT_WW_F3A", text = "float##3a", speed = 1.0f))
            if (LAYOUT_WW_SHOW_INDENTED) {
                with_indent(0.0f) {
                    edit_drag_float(safe_addr(LAYOUT_WW_FLOAT),
                        (id = "LAYOUT_WW_F3BI",
                         text = "float (indented)##3b", speed = 1.0f))
                }
            }
        }

        // PushItemWidth(-GetContentRegionAvail().x * 0.5f)
        text("SetNextItemWidth/PushItemWidth(-GetContentRegionAvail().x * 0.5f)")
        SameLine()
        text_disabled("(?)")
        item_tooltip(LAYOUT_WW_HM4) {
            text_unformatted("Align to right edge minus half")
        }
        with_item_width(-GetContentRegionAvail().x * 0.5f) {
            edit_drag_float(safe_addr(LAYOUT_WW_FLOAT),
                (id = "LAYOUT_WW_F4A", text = "float##4a", speed = 1.0f))
            if (LAYOUT_WW_SHOW_INDENTED) {
                with_indent(0.0f) {
                    edit_drag_float(safe_addr(LAYOUT_WW_FLOAT),
                        (id = "LAYOUT_WW_F4BI",
                         text = "float (indented)##4b", speed = 1.0f))
                }
            }
        }

        // PushItemWidth(-FLT_MIN)
        text("SetNextItemWidth/PushItemWidth(-FLT_MIN)")
        SameLine()
        text_disabled("(?)")
        item_tooltip(LAYOUT_WW_HM5) {
            text_unformatted("Align to right edge")
        }
        with_item_width(-FLT_MIN) {
            edit_drag_float(safe_addr(LAYOUT_WW_FLOAT),
                (id = "LAYOUT_WW_F5A", text = "##float5a", speed = 1.0f))
            if (LAYOUT_WW_SHOW_INDENTED) {
                with_indent(0.0f) {
                    edit_drag_float(safe_addr(LAYOUT_WW_FLOAT),
                        (id = "LAYOUT_WW_F5BI",
                         text = "float (indented)##5b", speed = 1.0f))
                }
            }
        }
    }
}


// =============================================================================
// Basic Horizontal Layout — cpp:3051-3143
// =============================================================================

def private BasicHorizontalLayoutSection() {
    tree_node(LAYOUT_BHL_TN, (text = "Basic Horizontal Layout",
                               flags = ImGuiTreeNodeFlags.None)) {
        text_wrapped((text = "(Use ImGui::SameLine() to keep adding items to the right of the " +
            "preceding item)"))

        // Two-item lines via SameLine.
        text("Two items: Hello"); SameLine()
        TextColored(ImVec4(1.0f, 1.0f, 0.0f, 1.0f), "Sailor")

        text("More spacing: Hello"); SameLine(0.0f, 20.0f)
        TextColored(ImVec4(1.0f, 1.0f, 0.0f, 1.0f), "Sailor")

        // Buttons aligned with text baseline.
        AlignTextToFramePadding()
        text("Normal buttons"); SameLine()
        button(LAYOUT_BHL_BANANA, (text = "Banana")); SameLine()
        button(LAYOUT_BHL_APPLE, (text = "Apple")); SameLine()
        button(LAYOUT_BHL_CORN, (text = "Corniflower"))

        // Small buttons inline with text.
        text("Small buttons"); SameLine()
        small_button(LAYOUT_BHL_SMALL, (text = "Like this one")); SameLine()
        text("can fit within a text block.")

        // Manual SameLine offsets.
        text("Aligned")
        SameLine(150.0f, -1.0f); text("x=150")
        SameLine(300.0f, -1.0f); text("x=300")
        text("Aligned")
        SameLine(150.0f, -1.0f); small_button(LAYOUT_BHL_SB150, (text = "x=150"))
        SameLine(300.0f, -1.0f); small_button(LAYOUT_BHL_SB300, (text = "x=300"))

        // Checkbox row.
        edit_checkbox(safe_addr(LAYOUT_BHL_C1),
            (id = "LAYOUT_BHL_C1", text = "My")); SameLine()
        edit_checkbox(safe_addr(LAYOUT_BHL_C2),
            (id = "LAYOUT_BHL_C2", text = "Tailor")); SameLine()
        edit_checkbox(safe_addr(LAYOUT_BHL_C3),
            (id = "LAYOUT_BHL_C3", text = "Is")); SameLine()
        edit_checkbox(safe_addr(LAYOUT_BHL_C4),
            (id = "LAYOUT_BHL_C4", text = "Rich"))

        // Combo + 3 SliderFloats sharing width 80, all on one line.
        let items <- ["AAAA", "BBBB", "CCCC", "DDDD"]
        with_item_width(80.0f) {
            edit_combo(safe_addr(LAYOUT_BHL_COMBO_ITEM),
                (id = "LAYOUT_BHL_COMBO", text = "Combo", items = items))
            SameLine()
            edit_slider_float(safe_addr(LAYOUT_BHL_F0),
                (id = "LAYOUT_BHL_X", text = "X",
                 v_min = 0.0f, v_max = 5.0f))
            SameLine()
            edit_slider_float(safe_addr(LAYOUT_BHL_F1),
                (id = "LAYOUT_BHL_Y", text = "Y",
                 v_min = 0.0f, v_max = 5.0f))
            SameLine()
            edit_slider_float(safe_addr(LAYOUT_BHL_F2),
                (id = "LAYOUT_BHL_Z", text = "Z",
                 v_min = 0.0f, v_max = 5.0f))
        }

        // Four ListBoxes sharing width 80, each with its own PushID.
        with_item_width(80.0f) {
            text("Lists:")
            for (i in range(4)) {
                if (i > 0) same_line(LAYOUT_LBOX_SL[i])
                with_id("lbox_{i}") {
                    list_box(LAYOUT_LBOX[i], (text = "",
                                              size = float2(0.0f, 0.0f))) {
                        for (j in range(length(items))) {
                            if (selectable(LAYOUT_LBOX_ITEM[i * 4 + j],
                                           (text = items[j]))) {
                                LAYOUT_BHL_SELECTION[i] = j
                            }
                        }
                    }
                }
            }
        }

        // Dummy spacing in horizontal layout.
        let button_sz = ImVec2(40.0f, 40.0f)
        Button("A", button_sz); SameLine()
        Dummy(button_sz); SameLine()
        Button("B", button_sz)

        // Manual wrapping — 20 "Box" buttons that wrap at window edge.
        text("Manual wrapping:")
        let style & = unsafe(GetStyle())
        let buttons_count = 20
        let window_visible_x2 = GetWindowPos().x + GetWindowContentRegionMax().x
        for (n in range(buttons_count)) {
            with_id("wrap_{n}") {
                Button("Box", button_sz)
                let last_button_x2 = GetItemRectMax().x
                let next_button_x2 = (last_button_x2 + style.ItemSpacing.x +
                                      button_sz.x)
                if (n + 1 < buttons_count && next_button_x2 < window_visible_x2) {
                    SameLine()
                }
            }
        }
    }
}


// =============================================================================
// Groups — cpp:3146-3190
// =============================================================================

def private GroupsSection() {
    tree_node(LAYOUT_GROUPS_TN, (text = "Groups",
                                  flags = ImGuiTreeNodeFlags.None)) {
        text("(?)")
        item_tooltip(LAYOUT_GROUPS_HM) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "BeginGroup() basically locks the horizontal position for " +
                    "new line. EndGroup() bundles the whole group so that you " +
                    "can use \"item\" functions such as IsItemHovered()/" +
                    "IsItemActive() or SameLine() etc. on the whole group."))
            }
        }

        // Outer group — bundles inner groups + ACTION/REACTION row.
        group(LAYOUT_GROUPS_OUTER) {
            group(LAYOUT_GROUPS_INNER1) {
                button(LAYOUT_GROUPS_AAA, (text = "AAA"))
                SameLine()
                button(LAYOUT_GROUPS_BBB, (text = "BBB"))
                SameLine()
                group(LAYOUT_GROUPS_INNER2) {
                    button(LAYOUT_GROUPS_CCC, (text = "CCC"))
                    button(LAYOUT_GROUPS_DDD, (text = "DDD"))
                }
                SameLine()
                button(LAYOUT_GROUPS_EEE, (text = "EEE"))
            }
            item_tooltip(LAYOUT_GROUPS_INNER_TIP) {
                text("First group hovered")
            }

            // Capture the group size and create widgets using the same size.
            let size = GetItemRectSize()
            // C++ uses PlotHistogram_FloatPtr with a 5-value array; the boost
            // PlotHistogram rail wants a lambda getter. TODO Phase 3: bridge
            // float-array → lambda or expose the FloatPtr overload directly.
            Dummy(size)

            let half_sz = ImVec2((size.x - GetStyle().ItemSpacing.x) * 0.5f,
                                  size.y)
            Button("ACTION", half_sz)
            SameLine()
            Button("REACTION", half_sz)
        }
        SameLine()

        Button("LEVERAGE\nBUZZWORD", GetItemRectSize())
        SameLine()

        list_box(LAYOUT_GROUPS_LIST, (text = "List",
                                       size = GetItemRectSize())) {
            selectable(LAYOUT_GROUPS_SEL_A,
                (text = "Selected", init = true))
            selectable(LAYOUT_GROUPS_SEL_B,
                (text = "Not Selected", init = false))
        }
    }
}


// =============================================================================
// Text Baseline Alignment — cpp:3193-3309
// =============================================================================

def private TextBaselineAlignmentSection() {
    tree_node(LAYOUT_TBA_TN, (text = "Text Baseline Alignment",
                               flags = ImGuiTreeNodeFlags.None)) {
        // ----- Block 1: text+button mixing -----
        bullet_text("Text baseline:"); SameLine()
        text("(?)")
        item_tooltip(LAYOUT_TBA_HM1) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "This is testing the vertical alignment that gets applied " +
                    "on text to keep it aligned with widgets. Lines only " +
                    "composed of text or \"small\" widgets use less vertical " +
                    "space than lines with framed widgets."))
            }
        }
        with_indent(0.0f) {
            text("KO Blahblah"); SameLine()
            button(LAYOUT_TBA_BTN1, (text = "Some framed item")); SameLine()
            text("(?)")
            item_tooltip(LAYOUT_TBA_HM2) {
                text_unformatted("Baseline of button will look misaligned with text..")
            }

            AlignTextToFramePadding()
            text("OK Blahblah"); SameLine()
            button(LAYOUT_TBA_BTN2, (text = "Some framed item")); SameLine()
            text("(?)")
            item_tooltip(LAYOUT_TBA_HM3) {
                text_unformatted((text = "We call AlignTextToFramePadding() to vertically align " +
                    "the text baseline by +FramePadding.y"))
            }

            button(LAYOUT_TBA_T1, (text = "TEST##1")); SameLine()
            text("TEST"); SameLine()
            small_button(LAYOUT_TBA_T2, (text = "TEST##2"))

            AlignTextToFramePadding()
            text("Text aligned to framed item"); SameLine()
            button(LAYOUT_TBA_I1, (text = "Item##1")); SameLine()
            text("Item"); SameLine()
            small_button(LAYOUT_TBA_I2, (text = "Item##2")); SameLine()
            button(LAYOUT_TBA_I3, (text = "Item##3"))
        }

        Spacing()

        // ----- Block 2: multi-line text -----
        bullet_text("Multi-line text:")
        with_indent(0.0f) {
            text("One\nTwo\nThree"); SameLine()
            text("Hello\nWorld"); SameLine()
            text("Banana")

            text("Banana"); SameLine()
            text("Hello\nWorld"); SameLine()
            text("One\nTwo\nThree")

            button(LAYOUT_TBA_HOP1, (text = "HOP##1")); SameLine()
            text("Banana"); SameLine()
            text("Hello\nWorld"); SameLine()
            text("Banana")

            button(LAYOUT_TBA_HOP2, (text = "HOP##2")); SameLine()
            text("Hello\nWorld"); SameLine()
            text("Banana")
        }

        Spacing()

        // ----- Block 3: misc items (sized buttons + tree) -----
        bullet_text("Misc items:")
        with_indent(0.0f) {
            Button("80x80", ImVec2(80.0f, 80.0f)); SameLine()
            Button("50x50", ImVec2(50.0f, 50.0f)); SameLine()
            button(LAYOUT_TBA_BTNDEF, (text = "Button()")); SameLine()
            small_button(LAYOUT_TBA_SMALL, (text = "SmallButton()"))

            let spacing_x = GetStyle().ItemInnerSpacing.x
            button(LAYOUT_TBA_B1, (text = "Button##1"))
            SameLine(0.0f, spacing_x)
            tree_node(LAYOUT_TBA_NODE1,
                      (text = "Node##1", flags = ImGuiTreeNodeFlags.None)) {
                for (i in range(6)) {
                    bullet_text(LAYOUT_TBA_NODE1_BT[i], (text = "Item {i}.."))
                }
            }

            AlignTextToFramePadding()
            // Common mistake to avoid: SameLine after TreeNode must come
            // before any contents below the node.
            let node_open = TreeNode("Node##2")
            SameLine(0.0f, spacing_x)
            button(LAYOUT_TBA_B2, (text = "Button##2"))
            if (node_open) {
                for (i in range(6)) {
                    bullet_text(LAYOUT_TBA_NODE2_BT[i], (text = "Item {i}.."))
                }
                TreePop()
            }

            button(LAYOUT_TBA_B3, (text = "Button##3"))
            SameLine(0.0f, spacing_x)
            bullet_text("Bullet text")

            AlignTextToFramePadding()
            bullet_text("Node")
            SameLine(0.0f, spacing_x)
            button(LAYOUT_TBA_B4, (text = "Button##4"))
        }
    }
}


// =============================================================================
// Scrolling — cpp:3312-3596
// =============================================================================

def private ScrollingSection() {
    tree_node(LAYOUT_SCROLL_TN, (text = "Scrolling",
                                  flags = ImGuiTreeNodeFlags.None)) {
        // ----- Vertical scrolling -----
        text("(?)")
        item_tooltip(LAYOUT_SCROLL_HM_V) {
            text_unformatted((text = "Use SetScrollHereY() or SetScrollFromPosY() to scroll to a " +
                "given vertical position."))
        }

        edit_checkbox(safe_addr(LAYOUT_SCROLL_ENABLE_EXTRA_DECOR),
            (id = "LAYOUT_SCROLL_DECOR", text = "Decoration"))
        edit_checkbox(safe_addr(LAYOUT_SCROLL_ENABLE_TRACK),
            (id = "LAYOUT_SCROLL_TRACK", text = "Track"))

        with_item_width(100.0f) {
            SameLine(140.0f, -1.0f)
            if (edit_drag_int(safe_addr(LAYOUT_SCROLL_TRACK_ITEM),
                (id = "LAYOUT_SCROLL_ITEM", text = "##item",
                 speed = 0.25f, v_min = 0, v_max = 99,
                 format = "Item = %d"))) {
                LAYOUT_SCROLL_ENABLE_TRACK = true
            }

            var scroll_to_off = Button("Scroll Offset", ImVec2(0.0f, 0.0f))
            SameLine(140.0f, -1.0f)
            if (edit_drag_float(safe_addr(LAYOUT_SCROLL_TO_OFF_PX),
                (id = "LAYOUT_SCROLL_OFF_PX", text = "##off",
                 speed = 1.0f, v_min = 0.0f, v_max = FLT_MAX,
                 format = "+%.0f px"))) {
                scroll_to_off = true
            }

            var scroll_to_pos = Button("Scroll To Pos", ImVec2(0.0f, 0.0f))
            SameLine(140.0f, -1.0f)
            if (edit_drag_float(safe_addr(LAYOUT_SCROLL_TO_POS_PX),
                (id = "LAYOUT_SCROLL_POS_PX", text = "##pos",
                 speed = 1.0f, v_min = -10.0f, v_max = FLT_MAX,
                 format = "X/Y = %.0f px"))) {
                scroll_to_pos = true
            }

            if (scroll_to_off || scroll_to_pos) {
                LAYOUT_SCROLL_ENABLE_TRACK = false
            }

            let style & = unsafe(GetStyle())
            var child_w = ((GetContentRegionAvail().x - 4.0f * style.ItemSpacing.x) /
                           5.0f)
            if (child_w < 1.0f) {
                child_w = 1.0f
            }
            with_id("VerticalScrolling") {
                for (i in range(5)) {
                    if (i > 0) SameLine()
                    group(LAYOUT_VS_GROUP[i]) {
                        let names <- ["Top", "25%", "Center", "75%", "Bottom"]
                        TextUnformatted(names[i])

                        let child_flags = (LAYOUT_SCROLL_ENABLE_EXTRA_DECOR ?
                            ImGuiWindowFlags.MenuBar : ImGuiWindowFlags.None)
                        child(LAYOUT_VS_CHILD[i],
                              (text = "##vs_{i}", size = float2(child_w, 200.0f),
                               child_flags = ImGuiChildFlags.Border,
                               window_flags = child_flags)) {
                            if (BeginMenuBar()) {
                                TextUnformatted("abc")
                                EndMenuBar()
                            }
                            if (scroll_to_off) {
                                SetScrollY(LAYOUT_SCROLL_TO_OFF_PX)
                            }
                            if (scroll_to_pos) {
                                SetScrollFromPosY(GetCursorStartPos().y +
                                                  LAYOUT_SCROLL_TO_POS_PX,
                                                  float(i) * 0.25f)
                            }
                            for (item in range(100)) {
                                if (LAYOUT_SCROLL_ENABLE_TRACK &&
                                    item == LAYOUT_SCROLL_TRACK_ITEM) {
                                    TextColored(ImVec4(1.0f, 1.0f, 0.0f, 1.0f),
                                                "Item {item}")
                                    SetScrollHereY(float(i) * 0.25f)
                                } else {
                                    text("Item {item}")
                                }
                            }
                        }
                        let sy = GetScrollY()
                        let smy = GetScrollMaxY()
                        text("{fmt_0f(sy)}/{fmt_0f(smy)}")
                    }
                }
            }
        }

        // ----- Horizontal scrolling -----
        Spacing()
        text("(?)")
        item_tooltip(LAYOUT_SCROLL_HM_H) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "Use SetScrollHereX() or SetScrollFromPosX() to scroll " +
                    "to a given horizontal position.\n\nBecause the clipping " +
                    "rectangle of most window hides half worth of " +
                    "WindowPadding on the left/right, using " +
                    "SetScrollFromPosX(+1) will usually result in clipped " +
                    "text whereas the equivalent SetScrollFromPosY(+1) wouldn't."))
            }
        }
        let style & = unsafe(GetStyle())
        with_id("HorizontalScrolling") {
            for (i in range(5)) {
                let child_height = (GetTextLineHeight() + style.ScrollbarSize +
                                    style.WindowPadding.y * 2.0f)
                var hflags = int(ImGuiWindowFlags.HorizontalScrollbar)
                if (LAYOUT_SCROLL_ENABLE_EXTRA_DECOR) {
                    hflags |= int(ImGuiWindowFlags.AlwaysVerticalScrollbar)
                }
                child(LAYOUT_HS_CHILD[i],
                      (text = "##hs_{i}",
                       size = float2(-100.0f, child_height),
                       child_flags = ImGuiChildFlags.Border,
                       window_flags = unsafe(reinterpret<ImGuiWindowFlags>(hflags)))) {
                    var hit_track = false
                    for (item in range(100)) {
                        if (item > 0) SameLine()
                        if (LAYOUT_SCROLL_ENABLE_TRACK &&
                            item == LAYOUT_SCROLL_TRACK_ITEM) {
                            TextColored(ImVec4(1.0f, 1.0f, 0.0f, 1.0f),
                                        "Item {item}")
                            SetScrollHereX(float(i) * 0.25f)
                            hit_track = true
                        } else {
                            text("Item {item}")
                        }
                    }
                    // scroll_to_off/scroll_to_pos for horizontal omitted to
                    // keep this child read-only — the C++ reads them post
                    // BeginChild, which is the same shape.
                    if (hit_track) {}
                }
                SameLine()
                let names <- ["Left", "25%", "Center", "75%", "Right"]
                let sx = GetScrollX()
                let smx = GetScrollMaxX()
                text("{names[i]}\n{fmt_0f(sx)}/{fmt_0f(smx)}")
                Spacing()
            }
        }

        // ----- FizzBuzz horizontal scrolling demo -----
        text("(?)")
        item_tooltip(LAYOUT_SCROLL_HM_FB) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "Horizontal scrolling for a window is enabled via the " +
                    "ImGuiWindowFlags_HorizontalScrollbar flag.\n\nYou may " +
                    "want to also explicitly specify content width by using " +
                    "SetNextWindowContentWidth() before Begin()."))
            }
        }
        edit_slider_int(safe_addr(LAYOUT_SCROLL_HORIZ_LINES),
            (id = "LAYOUT_SCROLL_LINES", text = "Lines",
             v_min = 1, v_max = 15))
        with_style((ImGuiStyleVar.FrameRounding, 3.0f),
                   (ImGuiStyleVar.FramePadding, ImVec2(2.0f, 1.0f))) {
            let scrolling_child_size = float2(0.0f,
                                              GetFrameHeightWithSpacing() * 7.0f + 30.0f)
            child(LAYOUT_SCROLL_FB_CHILD,
                  (text = "scrolling", size = scrolling_child_size,
                   child_flags = ImGuiChildFlags.Border,
                   window_flags = ImGuiWindowFlags.HorizontalScrollbar)) {
                for (line in range(LAYOUT_SCROLL_HORIZ_LINES)) {
                    let num_buttons = 10 + (((line & 1) != 0) ? line * 9 :
                                                                line * 3)
                    for (n in range(num_buttons)) {
                        if (n > 0) SameLine()
                        with_id("fb_{n}_{line}") {
                            let lbl = ((n % 15 == 0) ? "FizzBuzz" :
                                       ((n % 3 == 0) ? "Fizz" :
                                        ((n % 5 == 0) ? "Buzz" : "{n}")))
                            let hue = float(n) * 0.05f
                            with_style((ImGuiCol.Button, HSV(hue, 0.6f, 0.6f)),
                                       (ImGuiCol.ButtonHovered,
                                        HSV(hue, 0.7f, 0.7f)),
                                       (ImGuiCol.ButtonActive,
                                        HSV(hue, 0.8f, 0.8f))) {
                                Button(lbl,
                                       ImVec2(40.0f + sin(float(line + n)) * 20.0f,
                                              0.0f))
                            }
                        }
                    }
                }
            }
        }
        var scroll_x_delta = 0.0f
        if (SmallButton("<<")) {}
        if (IsItemActive()) {
            scroll_x_delta = -GetIO().DeltaTime * 1000.0f
        }
        SameLine()
        text("Scroll from code"); SameLine()
        if (SmallButton(">>")) {}
        if (IsItemActive()) {
            scroll_x_delta = +GetIO().DeltaTime * 1000.0f
        }
        SameLine()
        // Compute and display scroll_x/scroll_max_x via the child's State.
        let fb_state & = LAYOUT_SCROLL_FB_CHILD
        text("{fmt_0f(fb_state.scroll.x)}/{fmt_0f(fb_state.scroll_max.x)}")
        if (scroll_x_delta != 0.0f) {
            // Re-enter the child by name to nudge its scroll position. This
            // is the standard ImGui trick — BeginChild outside the child body
            // — and is not on the boost surface.
            BeginChild("scrolling", float2(0.0f, 0.0f), ImGuiChildFlags.None,
                       ImGuiWindowFlags.None)
            SetScrollX(GetScrollX() + scroll_x_delta)
            EndChild()
        }
        Spacing()

        // ----- Horizontal contents-size demo (optional sub-window) -----
        edit_checkbox(safe_addr(LAYOUT_SCROLL_SHOW_HSZ_DEMO),
            (id = "LAYOUT_SCROLL_SHOW_HSZ",
             text = "Show Horizontal contents size demo window"))
        if (LAYOUT_SCROLL_SHOW_HSZ_DEMO) {
            HorizontalContentsSizeDemo()
        }
    }
}

// Sub-window: cpp:3495-3593.
def private HorizontalContentsSizeDemo() {
    if (LAYOUT_HSZ_EXPLICIT_CONTENT_SIZE) {
        SetNextWindowContentSize(ImVec2(LAYOUT_HSZ_CONTENTS_SIZE_X, 0.0f))
    }
    let flags = (LAYOUT_HSZ_SHOW_HSCROLL ?
        ImGuiWindowFlags.HorizontalScrollbar : ImGuiWindowFlags.None)
    window(LAYOUT_HSZ_WIN,
           (text = "Horizontal contents size demo window",
            closable = true, flags = flags)) {
        with_style((ImGuiStyleVar.ItemSpacing, ImVec2(2.0f, 0.0f)),
                   (ImGuiStyleVar.FramePadding, ImVec2(2.0f, 0.0f))) {
            text("(?)")
            item_tooltip(LAYOUT_HSZ_HM) {
                with_text_wrap_pos(GetFontSize() * 35.0f) {
                    text_unformatted((text = "Test how different widgets react and impact the work " +
                        "rectangle growing when horizontal scrolling is " +
                        "enabled.\n\nUse 'Metrics->Tools->Show windows " +
                        "rectangles' to visualize rectangles."))
                }
            }
            edit_checkbox(safe_addr(LAYOUT_HSZ_SHOW_HSCROLL),
                (id = "LAYOUT_HSZ_HS", text = "H-scrollbar"))
            edit_checkbox(safe_addr(LAYOUT_HSZ_SHOW_BUTTON),
                (id = "LAYOUT_HSZ_BTN", text = "Button"))
            edit_checkbox(safe_addr(LAYOUT_HSZ_SHOW_TREE_NODES),
                (id = "LAYOUT_HSZ_TN", text = "Tree nodes"))
            edit_checkbox(safe_addr(LAYOUT_HSZ_SHOW_TEXT_WRAPPED),
                (id = "LAYOUT_HSZ_TW", text = "Text wrapped"))
            edit_checkbox(safe_addr(LAYOUT_HSZ_SHOW_COLUMNS),
                (id = "LAYOUT_HSZ_COL", text = "Columns"))
            edit_checkbox(safe_addr(LAYOUT_HSZ_SHOW_TAB_BAR),
                (id = "LAYOUT_HSZ_TB", text = "Tab bar"))
            edit_checkbox(safe_addr(LAYOUT_HSZ_SHOW_CHILD),
                (id = "LAYOUT_HSZ_CH", text = "Child"))
            edit_checkbox(safe_addr(LAYOUT_HSZ_EXPLICIT_CONTENT_SIZE),
                (id = "LAYOUT_HSZ_ECS", text = "Explicit content size"))
            text((text = "Scroll {fmt_1f(GetScrollX())}/{fmt_1f(GetScrollMaxX())} " +
                         "{fmt_1f(GetScrollY())}/{fmt_1f(GetScrollMaxY())}"))
            if (LAYOUT_HSZ_EXPLICIT_CONTENT_SIZE) {
                SameLine()
                SetNextItemWidth(100.0f)
                edit_drag_float(safe_addr(LAYOUT_HSZ_CONTENTS_SIZE_X),
                    (id = "LAYOUT_HSZ_CSX", text = "##csx", speed = 1.0f))
                // The DrawList rect markers are skipped (no boost path).
                Dummy(ImVec2(0.0f, 10.0f))
            }
        }
        Separator()
        if (LAYOUT_HSZ_SHOW_BUTTON) {
            Button("this is a 300-wide button", ImVec2(300.0f, 0.0f))
        }
        if (LAYOUT_HSZ_SHOW_TREE_NODES) {
            tree_node(LAYOUT_HSZ_OUTER_TN,
                      (text = "this is a tree node",
                       flags = ImGuiTreeNodeFlags.None)) {
                tree_node(LAYOUT_HSZ_INNER_TN,
                          (text = "another one of those tree node...",
                           flags = ImGuiTreeNodeFlags.None)) {
                    text("Some tree contents")
                }
            }
            collapsing_header(LAYOUT_HSZ_CH_NODE,
                              (text = "CollapsingHeader",
                               closable = true,
                               flags = ImGuiTreeNodeFlags.None)) {}
        }
        if (LAYOUT_HSZ_SHOW_TEXT_WRAPPED) {
            text_wrapped((text = "This text should automatically wrap on the edge of the work " +
                "rectangle."))
        }
        if (LAYOUT_HSZ_SHOW_COLUMNS) {
            text("Tables:")
            if (BeginTable("table", 4, ImGuiTableFlags.Borders,
                           float2(0.0f, 0.0f), 0.0f)) {
                for (_n in range(4)) {
                    TableNextColumn()
                    text("Width {fmt_2f(GetContentRegionAvail().x)}")
                }
                EndTable()
            }
            text("Columns:")
            Columns(4, "", true)
            for (_n in range(4)) {
                text("Width {fmt_2f(GetColumnWidth(-1))}")
                NextColumn()
            }
            Columns(1, "", true)
        }
        if (LAYOUT_HSZ_SHOW_TAB_BAR) {
            tab_bar(LAYOUT_HSZ_TB_BAR,
                    (text = "Hello", flags = ImGuiTabBarFlags.None)) {
                tab_item(LAYOUT_HSZ_TAB1,
                         (text = "OneOneOne", closable = false,
                          flags = ImGuiTabItemFlags.None)) {}
                tab_item(LAYOUT_HSZ_TAB2,
                         (text = "TwoTwoTwo", closable = false,
                          flags = ImGuiTabItemFlags.None)) {}
                tab_item(LAYOUT_HSZ_TAB3,
                         (text = "ThreeThreeThree", closable = false,
                          flags = ImGuiTabItemFlags.None)) {}
                tab_item(LAYOUT_HSZ_TAB4,
                         (text = "FourFourFour", closable = false,
                          flags = ImGuiTabItemFlags.None)) {}
            }
        }
        if (LAYOUT_HSZ_SHOW_CHILD) {
            child(LAYOUT_HSZ_CHILD,
                  (text = "child", size = float2(0.0f, 0.0f),
                   child_flags = ImGuiChildFlags.Border,
                   window_flags = ImGuiWindowFlags.None)) {}
        }
    }
    // The closable window state propagates via the [container] WindowState
    // — when the user clicks X, LAYOUT_HSZ_WIN.open flips false and Begin/End
    // skip. We mirror it into the section's bool here for consistency.
    if (!LAYOUT_HSZ_WIN.open) {
        LAYOUT_SCROLL_SHOW_HSZ_DEMO = false
        LAYOUT_HSZ_WIN.open = true
    }
}


// =============================================================================
// Text Clipping — cpp:3599-3661
// =============================================================================

def private TextClippingSection() {
    tree_node(LAYOUT_CLIP_TN, (text = "Clipping",
                                flags = ImGuiTreeNodeFlags.None)) {
        edit_drag_float2(safe_addr(LAYOUT_CLIP_SIZE),
            (id = "LAYOUT_CLIP_SIZE", text = "size",
             speed = 0.5f, v_min = 1.0f, v_max = 200.0f, format = "%.0f"))
        text_wrapped("(Click and drag to scroll)")
        text("(?)")
        item_tooltip(LAYOUT_CLIP_HM) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "(Left) Using ImGui::PushClipRect():\nWill alter ImGui " +
                    "hit-testing logic + ImDrawList rendering.\n(use this if " +
                    "you want your clipping rectangle to affect interactions)" +
                    "\n\n(Center) Using ImDrawList::PushClipRect():\nWill " +
                    "alter ImDrawList rendering only.\n(use this as a " +
                    "shortcut if you are only using ImDrawList calls)\n\n" +
                    "(Right) Using ImDrawList::AddText() with a fine " +
                    "ClipRect:\nWill alter only this specific " +
                    "ImDrawList::AddText() rendering.\nThis is often used " +
                    "internally to avoid altering the clipping rectangle and " +
                    "minimize draw calls."))
            }
        }

        // The C++ demo paints three custom InvisibleButton canvases and renders
        // text into each with different clipping strategies — PushClipRect /
        // draw_list->PushClipRect / draw_list->AddText with a clip_rect param.
        // The drawlist boost surface doesn't ship the needed AddText/
        // AddRectFilled forms on the boost rail; the canvases render as
        // drag-only invisible buttons. TODO Phase 3.
        for (n in range(3)) {
            if (n > 0) same_line(LAYOUT_LOOP_SL_CLIP[n])
            with_id("clip_{n}") {
                invisible_button(LAYOUT_CLIP_BTN[n],
                    (text = "##canvas", size = LAYOUT_CLIP_SIZE))
                if (IsItemActive() &&
                    IsMouseDragging(ImGuiMouseButton.Left, -1.0f)) {
                    LAYOUT_CLIP_OFFSET.x += GetIO().MouseDelta.x
                    LAYOUT_CLIP_OFFSET.y += GetIO().MouseDelta.y
                }
                // TODO Phase 3: draw_list AddRectFilled + AddText per branch.
            }
        }
    }
}


// =============================================================================
// Overlap Mode — cpp:3664-3692
// =============================================================================

def private OverlapModeSection() {
    tree_node(LAYOUT_OVERLAP_TN, (text = "Overlap Mode",
                                   flags = ImGuiTreeNodeFlags.None)) {
        text("(?)")
        item_tooltip(LAYOUT_OVERLAP_HM) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "Hit-testing is by default performed in item submission " +
                    "order, which generally is perceived as 'back-to-front'." +
                    "\n\nBy using SetNextItemAllowOverlap() you can notify " +
                    "that an item may be overlapped by another. Doing so " +
                    "alters the hovering logic: items using AllowOverlap mode " +
                    "requires an extra frame to accept hovered state."))
            }
        }
        edit_checkbox(safe_addr(LAYOUT_OVERLAP_ENABLE),
            (id = "LAYOUT_OVERLAP_EN", text = "Enable AllowOverlap"))

        let button1_pos = GetCursorScreenPos()
        let button2_pos = ImVec2(button1_pos.x + 50.0f, button1_pos.y + 50.0f)
        if (LAYOUT_OVERLAP_ENABLE) {
            SetNextItemAllowOverlap()
        }
        Button("Button 1", ImVec2(80.0f, 80.0f))
        SetCursorScreenPos(button2_pos)
        Button("Button 2", ImVec2(80.0f, 80.0f))

        if (LAYOUT_OVERLAP_ENABLE) {
            SetNextItemAllowOverlap()
        }
        selectable(LAYOUT_OVERLAP_SEL, (text = "Some Selectable", init = false))
        SameLine()
        small_button(LAYOUT_OVERLAP_PLUS, (text = "++"))
    }
}


// =============================================================================
// Tabs section — the C++ has no "Tabs" sub-section in Layout; the imgui_demo
// Tabs demo lives under "Widgets". Layout ends at OverlapMode (cpp:3692). This
// section is a no-op placeholder to match the masterplan's section list.
// =============================================================================

def private TabsSection() {
    // No content — Tabs demo is part of the Widgets section in imgui_demo.cpp.
}


// =============================================================================
// Format helpers — daslang formatters that match C++'s printf shapes.
// =============================================================================

def private fmt_0f(v : float) : string {
    // "%.0f" — round to nearest int, render w/o decimals.
    return "{int(v)}"
}

def private fmt_1f(v : float) : string {
    // "%.1f" — one decimal place. daslang has no fixed-point printf; format
    // by scaling and trimming.
    let scaled = int(v * 10.0f)
    return "{scaled / 10}.{abs(scaled % 10)}"
}

def private fmt_2f(v : float) : string {
    let scaled = int(v * 100.0f)
    let frac = abs(scaled % 100)
    let frac_str = frac < 10 ? "0{frac}" : "{frac}"
    return "{scaled / 100}.{frac_str}"
}

def private fmt_3d(v : int) : string {
    // "%03d" — zero-pad to width 3.
    if (v < 10) return "00{v}"
    if (v < 100) return "0{v}"
    return "{v}"
}

def private fmt_4d(v : int) : string {
    // "%04d" — zero-pad to width 4.
    if (v < 10) return "000{v}"
    if (v < 100) return "00{v}"
    if (v < 1000) return "0{v}"
    return "{v}"
}
