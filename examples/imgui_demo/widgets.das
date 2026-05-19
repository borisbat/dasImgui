options gen2
options indenting = 4

module widgets

require imgui
require imgui/imgui_widgets_builtin
require imgui/imgui_containers_builtin
require imgui/imgui_id_builtin
require imgui/imgui_layout_builtin       // tree_pop pass-through
require imgui/imgui_scope_builtin
require imgui/imgui_drawlist_builtin     // with_window_drawlist + add_rect / add_rect_filled
require imgui/imgui_style_builtin        // with_style call_macro
require imgui/imgui_colors               // rgba packer (formerly v1 IM_COL32)
require daslib/safe_addr
require math

// =============================================================================
// Mirrors imgui_demo.cpp:651-2835 — static void ShowDemoWindowWidgets().
//
// Phase 2a Step 3 slice: Basic, Tooltips, Tree Nodes, Collapsing Headers,
// Bullets, Text, Images (cpp:651-1276). Sub-sections after Images remain
// stubbed and land in follow-up commits.
//
// Boost-surface conventions for this port (masterplan §"Static-state pattern"):
//   - Value-owning widgets — checkbox / radio_button_int / slider_* / drag_* /
//     input_* / color_edit* / combo / button — go through `[widget]`. The first
//     argument is the auto-emitted state global's identifier; `init=` /
//     `bounds=` seed the one-shot state initializer. The value lives in
//     `IDENT.value` and persists across reloads via `@live`.
//   - Indexed widgets — `IDENT[i]` — used for the seven coloured-button and
//     eight textured-button loops; each index gets its own state global.
//   - Containers — `tree_node` / `collapsing_header` / `item_tooltip` /
//     `drag_drop_source` (Phase 1) — replace raw `Begin*/End*` pairs.
//   - Leaf widgets — `tree_node_ex` returns the open bool without claiming
//     `TreePop()`, used where post-header item-state queries are needed
//     (Tree/Advanced node + leaf rows).
//   - Scope wrappers — `with_id` / `with_style` (color + var) / `with_text_wrap_pos`
//     / `with_disabled` (Phase 1) — replace raw `Push*/Pop*` and the
//     `BeginDisabled/EndDisabled` pair.
//   - External-pointer cases — `edit_checkbox_flags` (Tree Nodes/Advanced),
//     `edit_slider_angle` (Basic), `edit_collapsing_header` (Collapsing
//     Headers / closable bool) — `[edit_widget]` rail taking `safe_addr(...)`
//     against module-scope plain vars or `unsafe(addr(struct.field))`.
//   - Hover-gated tooltips — `set_item_tooltip(IDENT, text, flags=...)` for the
//     `if (IsItemHovered(flags)) SetTooltip(text)` idiom. Default `flags =
//     ForTooltip`; override per call (DelayNone / Stationary / etc.).
//   - `IMGUI_DEMO_MARKER` test-engine markers dropped (off-limits per CLAUDE.md).
//   - `SetItemTooltip(s)` → `item_tooltip(IDENT) { Text(s) }` (binding gap).
// =============================================================================

// ----- App-state plain vars (NOT widget state) -----
// The "Disable block" subsection (cpp:2807, not yet ported) flips this; for
// now it stays false. Keeping it as a plain var avoids needing a checkbox
// state global that's read but not edited within this slice.
var WIDGETS_DISABLE_ALL = false

// ----- Tree Nodes/Advanced — external-pointer state -----
// `CheckboxFlags` (now `edit_checkbox_flags`) binds an `int?` form, so the
// base-flags state is stored as `int` and converted back to
// `ImGuiTreeNodeFlags` at the TreeNodeEx call site.
var WIDGETS_TREE_BASE_FLAGS = int(ImGuiTreeNodeFlags.OpenOnArrow |
                                  ImGuiTreeNodeFlags.OpenOnDoubleClick |
                                  ImGuiTreeNodeFlags.SpanAvailWidth)
var WIDGETS_TREE_SELECTION_MASK = 1 << 2

// ----- Basic/SliderAngle external-pointer -----
var WIDGETS_BASIC_ANGLE = 0.0f

// ----- Plain counters (not widget state) -----
// Repeater-driven counters that the C++ demo holds as `static int counter`.
// Could be expressed as `radio_button_int.click_count` differences, but
// preserving the imperative ++/-- semantics is simpler with a plain var.
var WIDGETS_BASIC_ARROW_COUNTER = 0
var WIDGETS_IMAGES_PRESSED_COUNT = 0

// ----- Indexed widget tables -----
// The `[widget]` indexed form `IDENT[k]` requires a module-scope `table<K; ST>`
// declared upfront (the macro does not auto-emit indexed tables — see
// widgets/imgui_boost.das "table global is not declared at module scope").
var private WIDGETS_BASIC_COLOR_BTN : table<int; ClickState>
var private WIDGETS_TREE_BASIC : table<int; TreeNodeState>
var private WIDGETS_TREE_BASIC_BTN : table<int; ClickState>
var private WIDGETS_TREE_DRAG_SRC : table<int; DragDropSourceState>
var private WIDGETS_IMAGES_BTN : table<int; ClickState>
// In-loop narrative/marker widgets — one state global per iteration to avoid
// `check_unique_render` (same ident rendered N times per frame).
var private WIDGETS_LOOP_BASIC_COLOR_SL : table<int; EmptyMarkerState>
var private WIDGETS_LOOP_TREE_BASIC_TEXT : table<int; NarrativeState>
var private WIDGETS_LOOP_TREE_BASIC_SL : table<int; EmptyMarkerState>
var private WIDGETS_LOOP_TREE_DRAG_TEXT : table<int; NarrativeState>
var private WIDGETS_LOOP_TREE_BULLETTEXT : table<int; NarrativeState>
var private WIDGETS_LOOP_CH_TEXT_INNER : table<int; NarrativeState>
var private WIDGETS_LOOP_CH_TEXT_INNER2 : table<int; NarrativeState>
var private WIDGETS_LOOP_TEXT_PARA : table<int; NarrativeState>
var private WIDGETS_LOOP_IMG_SL : table<int; EmptyMarkerState>
var private WIDGETS_BASIC_LB_ROW : table<int; ClickState>
var private WIDGETS_TREE_LOOP_NODE : table<int; TreeNodeState>
var private WIDGETS_TREE_LOOP_LEAF : table<int; TreeNodeState>


// =============================================================================
// Helpers
// =============================================================================

// =============================================================================
// ShowDemoWindowWidgets — dispatcher
// =============================================================================

def ShowDemoWindowWidgets() {
    collapsing_header(WIDGETS_SECTION,
        (text = "Widgets", closable = false, flags = ImGuiTreeNodeFlags.None)) {
            with_disabled(WIDGETS_DISABLE_ALL) {
                BasicSection()
                TooltipsSection()
                TreeNodesSection()
                CollapsingHeadersSection()
                BulletsSection()
                TextSection()
                ImagesSection()
            }
    }
}


// =============================================================================
// Basic — cpp:662-855
// =============================================================================

def private BasicSection() {
    tree_node(WIDGETS_BASIC_SECTION,
        (text = "Basic", flags = ImGuiTreeNodeFlags.None)) {

        separator_text("General")

        // Button + click counter
        if (button(WIDGETS_BASIC_BUTTON, (text = "Button"))) {
            WIDGETS_BASIC_BUTTON.click_count++
        }
        if ((WIDGETS_BASIC_BUTTON.click_count & 1) != 0) {
            same_line(WIDGETS_SL_1)
            text("Thanks for clicking me!")
        }

        // Checkbox
        checkbox(WIDGETS_BASIC_CHECK, (text = "checkbox", init = true))

        // RadioButton — three buttons sharing one int state (radio_button_int).
        radio_button_int(WIDGETS_BASIC_RADIO, (text = "radio a", v_button = 0)); same_line(WIDGETS_SL_2)
        radio_button_int(WIDGETS_BASIC_RADIO, (text = "radio b", v_button = 1)); same_line(WIDGETS_SL_3)
        radio_button_int(WIDGETS_BASIC_RADIO, (text = "radio c", v_button = 2))

        // Coloured Buttons — `with_style` scopes the per-button color stack;
        // indexed `WIDGETS_BASIC_COLOR_BTN[i]` gives each iteration its own state
        // global and telemetry path.
        for (i in range(7)) {
            if (i > 0) same_line(WIDGETS_LOOP_BASIC_COLOR_SL[i])
            let hue = float(i) / 7.0f
            with_style((ImGuiCol.Button, HSV(hue, 0.6f, 0.6f)),
                       (ImGuiCol.ButtonHovered, HSV(hue, 0.7f, 0.7f)),
                       (ImGuiCol.ButtonActive, HSV(hue, 0.8f, 0.8f))) {
                button(WIDGETS_BASIC_COLOR_BTN[i], (text = "Click"))
            }
        }

        // Arrow buttons with the Repeater flag — wrapped by with_button_repeat
        // scope wrapper; the arrow buttons themselves go through boost.
        align_text_to_frame_padding(WIDGETS_BASIC_ATFP)
        text("Hold to repeat:")
        same_line(WIDGETS_SL_4)
        let spacing = GetStyle().ItemInnerSpacing.x
        with_button_repeat(true) {
            if (arrow_button(WIDGETS_BASIC_ARROW_L, (text = "##left", dir = ImGuiDir.Left))) {
                WIDGETS_BASIC_ARROW_COUNTER--
            }
            same_line((offset_from_start_x = 0.0f, spacing = spacing))
            if (arrow_button(WIDGETS_BASIC_ARROW_R, (text = "##right", dir = ImGuiDir.Right))) {
                WIDGETS_BASIC_ARROW_COUNTER++
            }
        }
        same_line(WIDGETS_SL_6)
        text("{WIDGETS_BASIC_ARROW_COUNTER}")

        // SetItemTooltip → item_tooltip container (binding-gap shim).
        button(WIDGETS_BASIC_TOOLTIP_BTN, (text = "Tooltip"))
        item_tooltip(WIDGETS_BASIC_TOOLTIP_TIP) {
            text("I am a tooltip")
        }

        label_text(WIDGETS_BASIC_LABEL, (key = "label", value = "Value"))

        separator_text("Inputs")

        input_text(WIDGETS_BASIC_STR0, (text = "input text", init = "Hello, world!"))
        same_line(WIDGETS_SL_7)
        text_disabled("(?)")
        item_tooltip(WIDGETS_BASIC_HM1_TIP) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "USER:\n" +
                    "Hold SHIFT or use mouse to select text.\n" +
                    "CTRL+Left/Right to word jump.\n" +
                    "CTRL+A or Double-Click to select all.\n" +
                    "CTRL+X,CTRL+C,CTRL+V clipboard.\n" +
                    "CTRL+Z,CTRL+Y undo/redo.\n" +
                    "ESCAPE to revert.\n\n" +
                    "PROGRAMMER:\n" +
                    "You can use the ImGuiInputTextFlags_CallbackResize facility if you " +
                    "need to wire InputText() to a dynamic string type. See misc/cpp/" +
                    "imgui_stdlib.h for an example (this is not demonstrated in " +
                    "imgui_demo.cpp)."))
            }
        }

        input_text_with_hint(WIDGETS_BASIC_STR1,
            (text = "input text (w/ hint)", hint = "enter text here"))

        input_int(WIDGETS_BASIC_I0, (text = "input int", init = 123))
        input_float(WIDGETS_BASIC_F0,
            (text = "input float", init = 0.001f, step = 0.01f, step_fast = 1.0f,
             format = "%.3f"))
        input_double(WIDGETS_BASIC_D0,
            (text = "input double", init = 999999.00000001lf,
             step = 0.01lf, step_fast = 1.0lf, format = "%.8f"))
        input_float(WIDGETS_BASIC_F_SCI,
            (text = "input scientific", init = 1.0e10f,
             step = 0.0f, step_fast = 0.0f, format = "%e"))
        same_line(WIDGETS_SL_8)
        text_disabled("(?)")
        item_tooltip(WIDGETS_BASIC_HM2_TIP) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "You can input value using the scientific notation,\n" +
                    "  e.g. \"1e+8\" becomes \"100000000\"."))
            }
        }
        input_float3(WIDGETS_BASIC_VEC4A,
            (text = "input float3", init = float3(0.10f, 0.20f, 0.30f)))

        separator_text("Drags")

        drag_int(WIDGETS_BASIC_DRAG_I1, (text = "drag int", init = 50, speed = 1.0f))
        same_line(WIDGETS_SL_9)
        text_disabled("(?)")
        item_tooltip(WIDGETS_BASIC_HM3_TIP) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "Click and drag to edit value.\n" +
                    "Hold SHIFT/ALT for faster/slower edit.\n" +
                    "Double-click or CTRL+click to input value."))
            }
        }

        drag_int(WIDGETS_BASIC_DRAG_I2,
            (text = "drag int 0..100", init = 42, speed = 1.0f, bounds = (0, 100),
             format = "%d%%", flags = ImGuiSliderFlags.AlwaysClamp))
        drag_float(WIDGETS_BASIC_DRAG_F1,
            (text = "drag float", init = 1.0f, speed = 0.005f))
        drag_float(WIDGETS_BASIC_DRAG_F2,
            (text = "drag small float", init = 0.0067f, speed = 0.0001f,
             format = "%.06f ns"))

        separator_text("Sliders")

        slider_int(WIDGETS_BASIC_SLIDER_I1,
            (text = "slider int", init = 0, bounds = (-1, 3)))
        same_line(WIDGETS_SL_10)
        text_disabled("(?)")
        item_tooltip(WIDGETS_BASIC_HM4_TIP) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted("CTRL+click to input value.")
            }
        }

        slider_float(WIDGETS_BASIC_SLIDER_F1,
            (text = "slider float", init = 0.123f, bounds = (0.0f, 1.0f),
             format = "ratio = %.3f"))
        slider_float(WIDGETS_BASIC_SLIDER_F2,
            (text = "slider float (log)", init = 0.0f, bounds = (-10.0f, 10.0f),
             format = "%.4f", flags = ImGuiSliderFlags.Logarithmic))

        edit_slider_angle(safe_addr(WIDGETS_BASIC_ANGLE),
            (id = "WIDGETS_BASIC_ANGLE_SLIDER", text = "slider angle"))

        // Slider (enum) — the format-string trick: omit %d so the label IS the
        // value. Format is dynamic so it goes in the regular arg, not init=.
        let elem_names = fixed_array("Fire", "Earth", "Air", "Water")
        let elem_v = WIDGETS_BASIC_ELEM.value
        let elem_name = (elem_v >= 0 && elem_v < 4) ? elem_names[elem_v] : "Unknown"
        slider_int(WIDGETS_BASIC_ELEM,
            (text = "slider enum", init = 0, bounds = (0, 3), format = elem_name))
        same_line(WIDGETS_SL_11)
        text_disabled("(?)")
        item_tooltip(WIDGETS_BASIC_HM5_TIP) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "Using the format string parameter to display a name instead of the " +
                    "underlying integer."))
            }
        }

        separator_text("Selectors/Pickers")

        color_edit3(WIDGETS_BASIC_COL1,
            (text = "color 1", init = float3(1.0f, 0.0f, 0.2f)))
        same_line(WIDGETS_SL_12)
        text_disabled("(?)")
        item_tooltip(WIDGETS_BASIC_HM6_TIP) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "Click on the color square to open a color picker.\n" +
                    "Click and hold to use drag and drop.\n" +
                    "Right-click on the color square to show options.\n" +
                    "CTRL+click on individual component to input value.\n"))
            }
        }
        color_edit4(WIDGETS_BASIC_COL2,
            (text = "color 2", init = float4(0.4f, 0.7f, 0.0f, 0.5f)))

        // One-liner Combo
        combo(WIDGETS_BASIC_COMBO,
            (text = "combo", init = 0,
             items <- ["AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG",
                       "HHHH", "IIIIIII", "JJJJ", "KKKKKKK"]))
        same_line(WIDGETS_SL_13)
        text_disabled("(?)")
        item_tooltip(WIDGETS_BASIC_HM7_TIP) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "Using the simplified one-liner Combo API here.\n" +
                    "Refer to the \"Combo\" section below for an explanation of how to " +
                    "use the more flexible and general BeginCombo/EndCombo API."))
            }
        }

        // One-liner ListBox — the [widget] items-array form was retired in Phase 1
        // (boost `list_box` is now the manual BeginListBox/EndListBox container).
        // Showcase the manual form here too — Selectable per item, sharing the
        // listbox's `value` for the selected row.
        list_box(WIDGETS_BASIC_LISTBOX,
            (text = "listbox", size = float2(0.0f, GetTextLineHeightWithSpacing() * 4.25f))) {
            let lb_items = fixed_array("Apple", "Banana", "Cherry", "Kiwi", "Mango",
                                       "Orange", "Pineapple", "Strawberry", "Watermelon")
            for (i in range(length(lb_items))) {
                let is_sel = WIDGETS_BASIC_LISTBOX.value == i
                if (selectable_label(WIDGETS_BASIC_LB_ROW[i],
                                     (text = lb_items[i], selected = is_sel))) {
                    WIDGETS_BASIC_LISTBOX.value = i
                }
            }
        }
        same_line(WIDGETS_SL_14)
        text_disabled("(?)")
        item_tooltip(WIDGETS_BASIC_HM8_TIP) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "Using the manual BeginListBox/EndListBox idiom here.\n" +
                    "Refer to the \"List boxes\" section below for the full discussion."))
            }
        }
    }
}


// =============================================================================
// Tooltips — cpp:858-948
// =============================================================================

def private TooltipsSection() {
    tree_node(WIDGETS_TOOLTIPS_SECTION,
        (text = "Tooltips", flags = ImGuiTreeNodeFlags.None)) {

        separator_text("General")
        text_disabled("(?)")
        item_tooltip(WIDGETS_TIPS_HM1_TIP) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "Tooltip are typically created by using a IsItemHovered() + " +
                    "SetTooltip() sequence.\n\nWe provide a helper SetItemTooltip() " +
                    "function to perform the two with standards flags."))
            }
        }

        // The C++ demo passes `ImVec2(-FLT_MIN, 0.0f)` to give every button
        // full row width; the boost `button` widget doesn't expose `size` yet, so
        // these render at their default content width instead. Visual parity isn't
        // load-bearing here.
        button(WIDGETS_TIP_BASIC, (text = "Basic"))
        item_tooltip(WIDGETS_TIP_BASIC_TIP) {
            text("I am a tooltip")
        }

        button(WIDGETS_TIP_FANCY, (text = "Fancy"))
        item_tooltip(WIDGETS_TIP_FANCY_TIP) {
            text("I am a fancy tooltip")
            plot_lines(WIDGETS_TIP_CURVE, "Curve",
                       [0.6f, 0.1f, 1.0f, 0.5f, 0.92f, 0.1f, 0.2f])
            text("Sin(time) = {sin(float(GetTime()))}")
        }

        separator_text("Always On")

        // Three-way radio: Off / Always On (Simple) / Always On (Advanced)
        radio_button_int(WIDGETS_TIP_ALWAYS_ON, (text = "Off", v_button = 0)); same_line(WIDGETS_SL_15)
        radio_button_int(WIDGETS_TIP_ALWAYS_ON, (text = "Always On (Simple)", v_button = 1)); same_line(WIDGETS_SL_16)
        radio_button_int(WIDGETS_TIP_ALWAYS_ON, (text = "Always On (Advanced)", v_button = 2))
        if (WIDGETS_TIP_ALWAYS_ON.value == 1) {
            set_tooltip(WIDGETS_TIP_FOLLOW_TT, "I am following you around.")
        } elif (WIDGETS_TIP_ALWAYS_ON.value == 2) {
            // Advanced form draws into the tooltip body. Value-gated rather than
            // IsItemHovered()-gated — the boost `tooltip` container handles
            // BeginTooltip/EndTooltip itself.
            tooltip(WIDGETS_TIP_1) {
                progress_bar((fraction = sin(float(GetTime())) * 0.5f + 0.5f,
                              size = float2(GetFontSize() * 25.0f, 0.0f),
                              overlay = ""))
            }
        }

        separator_text("Custom")
        text_disabled("(?)")
        item_tooltip(WIDGETS_TIPS_HM2_TIP) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted((text = "Passing ImGuiHoveredFlags_ForTooltip to IsItemHovered() is the " +
                    "preferred way to standardize tooltip activation details across " +
                    "your application. You may however decide to use custom flags for " +
                    "a specific tooltip instance."))
            }
        }

        button(WIDGETS_TIP_MANUAL, (text = "Manual"))
        set_item_tooltip(WIDGETS_TIP_MANUAL_TT, "I am a manually emitted tooltip.")

        button(WIDGETS_TIP_DELAY_NONE, (text = "DelayNone"))
        set_item_tooltip(WIDGETS_TIP_DELAY_NONE_TT,
                         (text = "I am a tooltip with no delay.",
                          flags = ImGuiHoveredFlags.DelayNone))

        button(WIDGETS_TIP_DELAY_SHORT, (text = "DelayShort"))
        let delay_short = GetStyle().HoverDelayShort
        set_item_tooltip(WIDGETS_TIP_DELAY_SHORT_TT,
                         (text = "I am a tooltip with a short delay ({delay_short} sec).",
                          flags = ImGuiHoveredFlags.DelayShort | ImGuiHoveredFlags.NoSharedDelay))

        button(WIDGETS_TIP_DELAY_LONG, (text = "DelayLong"))
        let delay_long = GetStyle().HoverDelayNormal
        set_item_tooltip(WIDGETS_TIP_DELAY_LONG_TT,
                         (text = "I am a tooltip with a long delay ({delay_long} sec).",
                          flags = ImGuiHoveredFlags.DelayNormal | ImGuiHoveredFlags.NoSharedDelay))

        button(WIDGETS_TIP_STATIONARY, (text = "Stationary"))
        set_item_tooltip(WIDGETS_TIP_STATIONARY_TT,
                         (text = "I am a tooltip requiring mouse to be stationary before activating.",
                          flags = ImGuiHoveredFlags.Stationary))

        // Disabled-item tooltip — ForTooltip flag pulls AllowWhenDisabled from style.
        with_disabled(true) {
            button(WIDGETS_TIP_DISABLED, (text = "Disabled item"))
        }
        set_item_tooltip(WIDGETS_TIP_DISABLED_TT, "I am a a tooltip for a disabled item.")
    }
}


// =============================================================================
// Tree Nodes — cpp:957-1078
// =============================================================================

def private TreeNodesSection() {
    tree_node(WIDGETS_TREES_SECTION,
        (text = "Tree Nodes", flags = ImGuiTreeNodeFlags.None)) {

        // ----- Basic trees -----
        tree_node(WIDGETS_TREES_BASIC,
            (text = "Basic trees", flags = ImGuiTreeNodeFlags.None)) {
            for (i in range(5)) {
                if (i == 0) SetNextItemOpen(true, ImGuiCond.Once)
                // Indexed identifier — each iteration gets its own state global
                // and telemetry path (WIDGETS_TREE_BASIC[0..4]).
                tree_node(WIDGETS_TREE_BASIC[i],
                          (text = "Child {i}", flags = ImGuiTreeNodeFlags.None)) {
                    text(WIDGETS_LOOP_TREE_BASIC_TEXT[i], (text = "blah blah"))
                    same_line(WIDGETS_LOOP_TREE_BASIC_SL[i])
                    small_button(WIDGETS_TREE_BASIC_BTN[i], (text = "button"))
                }
            }
        }

        // ----- Advanced, with Selectable nodes -----
        tree_node(WIDGETS_TREES_ADVANCED,
            (text = "Advanced, with Selectable nodes",
             flags = ImGuiTreeNodeFlags.None)) {
            text_disabled("(?)")
            item_tooltip(WIDGETS_TREE_HM1_TIP) {
                with_text_wrap_pos(GetFontSize() * 35.0f) {
                    text_unformatted((text = "This is a more typical looking tree with selectable nodes.\n" +
                        "Click to select, CTRL+Click to toggle, click on arrows or " +
                        "double-click to open."))
                }
            }

            // CheckboxFlags drives a single shared int (base_flags) through
            // the boost `edit_checkbox_flags` external-pointer rail; each call
            // toggles one specific bit. The two plain bool checkboxes below
            // use the regular `checkbox` widget form.
            edit_checkbox_flags(safe_addr(WIDGETS_TREE_BASE_FLAGS),
                (id = "WIDGETS_TREE_FLAG_OPEN_ON_ARROW",
                 text = "ImGuiTreeNodeFlags_OpenOnArrow",
                 flags_value = int(ImGuiTreeNodeFlags.OpenOnArrow)))
            edit_checkbox_flags(safe_addr(WIDGETS_TREE_BASE_FLAGS),
                (id = "WIDGETS_TREE_FLAG_OPEN_ON_DOUBLE_CLICK",
                 text = "ImGuiTreeNodeFlags_OpenOnDoubleClick",
                 flags_value = int(ImGuiTreeNodeFlags.OpenOnDoubleClick)))
            edit_checkbox_flags(safe_addr(WIDGETS_TREE_BASE_FLAGS),
                (id = "WIDGETS_TREE_FLAG_SPAN_AVAIL_WIDTH",
                 text = "ImGuiTreeNodeFlags_SpanAvailWidth",
                 flags_value = int(ImGuiTreeNodeFlags.SpanAvailWidth)))
            same_line(WIDGETS_SL_17)
            text_disabled("(?)")
            item_tooltip(WIDGETS_TREE_HM2_TIP) {
                with_text_wrap_pos(GetFontSize() * 35.0f) {
                    text_unformatted((text = "Extend hit area to all available width instead of allowing " +
                        "more items to be laid out after the node."))
                }
            }
            edit_checkbox_flags(safe_addr(WIDGETS_TREE_BASE_FLAGS),
                (id = "WIDGETS_TREE_FLAG_SPAN_FULL_WIDTH",
                 text = "ImGuiTreeNodeFlags_SpanFullWidth",
                 flags_value = int(ImGuiTreeNodeFlags.SpanFullWidth)))
            edit_checkbox_flags(safe_addr(WIDGETS_TREE_BASE_FLAGS),
                (id = "WIDGETS_TREE_FLAG_SPAN_TEXT_WIDTH",
                 text = "ImGuiTreeNodeFlags_SpanTextWidth",
                 flags_value = int(ImGuiTreeNodeFlags.SpanTextWidth)))
            same_line(WIDGETS_SL_18)
            text_disabled("(?)")
            item_tooltip(WIDGETS_TREE_HM3_TIP) {
                with_text_wrap_pos(GetFontSize() * 35.0f) {
                    text_unformatted("Reduce hit area to the text label and a bit of margin.")
                }
            }
            edit_checkbox_flags(safe_addr(WIDGETS_TREE_BASE_FLAGS),
                (id = "WIDGETS_TREE_FLAG_SPAN_ALL_COLUMNS",
                 text = "ImGuiTreeNodeFlags_SpanAllColumns",
                 flags_value = int(ImGuiTreeNodeFlags.SpanAllColumns)))
            same_line(WIDGETS_SL_19)
            text_disabled("(?)")
            item_tooltip(WIDGETS_TREE_HM4_TIP) {
                with_text_wrap_pos(GetFontSize() * 35.0f) {
                    text_unformatted("For use in Tables only.")
                }
            }
            edit_checkbox_flags(safe_addr(WIDGETS_TREE_BASE_FLAGS),
                (id = "WIDGETS_TREE_FLAG_ALLOW_OVERLAP",
                 text = "ImGuiTreeNodeFlags_AllowOverlap",
                 flags_value = int(ImGuiTreeNodeFlags.AllowOverlap)))
            edit_checkbox_flags(safe_addr(WIDGETS_TREE_BASE_FLAGS),
                (id = "WIDGETS_TREE_FLAG_FRAMED",
                 text = "ImGuiTreeNodeFlags_Framed",
                 flags_value = int(ImGuiTreeNodeFlags.Framed)))
            same_line(WIDGETS_SL_20)
            text_disabled("(?)")
            item_tooltip(WIDGETS_TREE_HM5_TIP) {
                with_text_wrap_pos(GetFontSize() * 35.0f) {
                    text_unformatted("Draw frame with background (e.g. for CollapsingHeader)")
                }
            }

            checkbox(WIDGETS_TREE_ALIGN, (text = "Align label with current X position"))
            checkbox(WIDGETS_TREE_DRAG_TEST, (text = "Test tree node as drag source"))

            text("Hello!")
            if (WIDGETS_TREE_ALIGN.value) {
                unindent(WIDGETS_TREE_REUNINDENT, GetTreeNodeToLabelSpacing())
            }

            var node_clicked = -1
            for (i in range(6)) {
                // Disable default "open on single-click" + set Selected from mask.
                // node_flags stays as int (matching WIDGETS_TREE_BASE_FLAGS) so
                // `|=` works; cast back to ImGuiTreeNodeFlags at the call site.
                var node_flags = WIDGETS_TREE_BASE_FLAGS
                let is_selected = (WIDGETS_TREE_SELECTION_MASK & (1 << i)) != 0
                if (is_selected) {
                    node_flags |= int(ImGuiTreeNodeFlags.Selected)
                }
                // Per-row ID scope. `tree_node_ex` (leaf-form boost widget)
                // returns the open bool without claiming a TreePop — caller
                // matches one when the node opened AND flags don't include
                // `NoTreePushOnOpen`. The boost `tree_node` container can't be
                // used here because we need post-header item-state queries
                // (IsItemClicked, drag_drop_source, inline same_line + button);
                // the container hides the TreeNodeEx call site so those would
                // attach to the wrong item.
                with_id("row_{i}") {
                    if (i < 3) {
                        let node_open = tree_node_ex(WIDGETS_TREE_LOOP_NODE[i],
                            (text = "Selectable Node {i}",
                             flags = unsafe(reinterpret<ImGuiTreeNodeFlags>(node_flags))))
                        if (IsItemClicked() && !IsItemToggledOpen()) {
                            node_clicked = i
                        }
                        if (WIDGETS_TREE_DRAG_TEST.value) {
                            drag_drop_source(WIDGETS_TREE_DRAG_SRC[i],
                                             (flags = ImGuiDragDropFlags.None)) {
                                SetDragDropPayload("_TREENODE", null, 0ul)
                                text(WIDGETS_LOOP_TREE_DRAG_TEXT[i], (text = "This is a drag and drop source"))
                            }
                        }
                        if (i == 2) {
                            // Item 2 has an inline button to demonstrate SpanTextWidth.
                            same_line(WIDGETS_SL_21)
                            small_button(WIDGETS_TREE_INLINE_BTN, (text = "button"))
                        }
                        if (node_open) {
                            bullet_text(WIDGETS_LOOP_TREE_BULLETTEXT[i], (text = "Blah blah\nBlah Blah"))
                            tree_pop()
                        }
                    } else {
                        // Leaves: Leaf + NoTreePushOnOpen — no TreePop is paired.
                        node_flags |= int(ImGuiTreeNodeFlags.Leaf |
                                          ImGuiTreeNodeFlags.NoTreePushOnOpen)
                        tree_node_ex(WIDGETS_TREE_LOOP_LEAF[i],
                            (text = "Selectable Leaf {i}",
                             flags = unsafe(reinterpret<ImGuiTreeNodeFlags>(node_flags))))
                        if (IsItemClicked() && !IsItemToggledOpen()) {
                            node_clicked = i
                        }
                        if (WIDGETS_TREE_DRAG_TEST.value) {
                            drag_drop_source(WIDGETS_TREE_DRAG_SRC[i],
                                             (flags = ImGuiDragDropFlags.None)) {
                                SetDragDropPayload("_TREENODE", null, 0ul)
                                text(WIDGETS_LOOP_TREE_DRAG_TEXT[i], (text = "This is a drag and drop source"))
                            }
                        }
                    }
                }
            }
            if (node_clicked != -1) {
                if (GetIO().KeyCtrl) {
                    WIDGETS_TREE_SELECTION_MASK ^= (1 << node_clicked)
                } else {
                    WIDGETS_TREE_SELECTION_MASK = (1 << node_clicked)
                }
            }
            if (WIDGETS_TREE_ALIGN.value) {
                indent(WIDGETS_TREE_REINDENT, GetTreeNodeToLabelSpacing())
            }
        }
    }
}


// =============================================================================
// Collapsing Headers — cpp:1080-1102
// =============================================================================

def private CollapsingHeadersSection() {
    tree_node(WIDGETS_CH_SECTION,
        (text = "Collapsing Headers", flags = ImGuiTreeNodeFlags.None)) {
            checkbox(WIDGETS_CH_CLOSABLE_GROUP,
                (text = "Show 2nd header", init = true))
            collapsing_header(WIDGETS_CH_HEADER,
                (text = "Header", closable = false, flags = ImGuiTreeNodeFlags.None)) {
                text("IsItemHovered: {IsItemHovered()}")
                for (i in range(5)) {
                    text(WIDGETS_LOOP_CH_TEXT_INNER[i], (text = "Some content {i}"))
                }
            }
            // The second header's X-button is wired to the checkbox's bool —
            // boost `edit_collapsing_header` is the [edit_widget] form taking
            // an external p_visible pointer; the body runs only while the bool
            // is true AND the header is expanded.
            if (edit_collapsing_header(safe_addr(WIDGETS_CH_CLOSABLE_GROUP.value),
                                       (id = "WIDGETS_CH_HEADER2",
                                        text = "Header with a close button"))) {
                text("IsItemHovered: {IsItemHovered()}")
                for (i in range(5)) {
                    text(WIDGETS_LOOP_CH_TEXT_INNER2[i], (text = "More content {i}"))
                }
            }
    }
}


// =============================================================================
// Bullets — cpp:1104-1117
// =============================================================================

def private BulletsSection() {
    tree_node(WIDGETS_BULLETS_SECTION,
        (text = "Bullets", flags = ImGuiTreeNodeFlags.None)) {
            bullet_text("Bullet point 1")
            bullet_text("Bullet point 2\nOn multiple lines")
            tree_node(WIDGETS_BULLETS_INNER,
                (text = "Tree node", flags = ImGuiTreeNodeFlags.None)) {
                bullet_text("Another bullet point")
            }
        bullet(WIDGETS_BULLET_4); text("Bullet point 3 (two calls)")
        bullet(WIDGETS_BULLET_5); small_button(WIDGETS_BULLETS_BTN, (text = "Button"))

    }
}


// =============================================================================
// Text — cpp:1119-1192
// =============================================================================

def private TextSection() {
    tree_node(WIDGETS_TEXT_SECTION,
        (text = "Text", flags = ImGuiTreeNodeFlags.None)) {

            tree_node(WIDGETS_TEXT_COLORFUL,
                (text = "Colorful Text", flags = ImGuiTreeNodeFlags.None)) {
                text_colored(WIDGETS_TEXT_PINK, float4(1.0f, 0.0f, 1.0f, 1.0f), "Pink")
                text_colored(WIDGETS_TEXT_YELLOW, float4(1.0f, 1.0f, 0.0f, 1.0f), "Yellow")
                text_disabled("Disabled")
                same_line(WIDGETS_SL_22)
                text_disabled("(?)")
                item_tooltip(WIDGETS_TEXT_HM1_TIP) {
                    with_text_wrap_pos(GetFontSize() * 35.0f) {
                        text_unformatted("The TextDisabled color is stored in ImGuiStyle.")
                    }
                }
            }

            tree_node(WIDGETS_TEXT_WORDWRAP,
                (text = "Word Wrapping", flags = ImGuiTreeNodeFlags.None)) {
                text_wrapped((text = "This text should automatically wrap on the edge of the " +
                    "window. The current implementation for text wrapping " +
                    "follows simple rules suitable for English and possibly " +
                    "other languages."))
                spacing(WIDGETS_SP_1)

                slider_float(WIDGETS_TEXT_WRAP_WIDTH,
                    (text = "Wrap width", init = 200.0f, bounds = (-20.0f, 600.0f),
                     format = "%.0f"))

                for (n in range(2)) {
                    text(WIDGETS_LOOP_TEXT_PARA[n], (text = "Test paragraph {n}:"))
                    let pos = GetCursorScreenPos()
                    let wrap = WIDGETS_TEXT_WRAP_WIDTH.value
                    let marker_min = float2(pos.x + wrap, pos.y)
                    let marker_max = float2(pos.x + wrap + 10.0f,
                                            pos.y + GetTextLineHeight())
                    with_text_wrap_pos(GetCursorPos().x + wrap) {
                        if (n == 0) {
                            text((text = "The lazy dog is a good dog. This paragraph " +
                                         "should fit within {wrap} pixels. Testing a 1 " +
                                         "character word. The quick brown fox jumps over " +
                                         "the lazy dog."))
                        } else {
                            text((text = "aaaaaaaa bbbbbbbb, c cccccccc,dddddddd. d " +
                                         "eeeeeeee   ffffffff. gggggggg!hhhhhhhh"))
                        }
                        with_window_drawlist() $(var dl) {
                            dl |> add_rect(GetItemRectMin(), GetItemRectMax(),
                                           rgba(255u, 255u, 0u, 255u))
                            dl |> add_rect_filled(marker_min, marker_max,
                                                  rgba(255u, 0u, 255u, 255u))
                        }
                    }
                }
            }

            tree_node(WIDGETS_TEXT_UTF8,
                (text = "UTF-8 Text", flags = ImGuiTreeNodeFlags.None)) {
                text_wrapped((text = "CJK text will only appear if the font was loaded with the " +
                    "appropriate CJK character ranges. Call io.Fonts->" +
                    "AddFontFromFileTTF() manually to load extra character ranges. " +
                    "Read docs/FONTS.md for details."))
                // daslang source files are UTF-8 so the literals are stored as-is.
                text("Hiragana: かきくけこ (kakikukeko)")
                text("Kanjis: 日本語 (nihongo)")
                input_text(WIDGETS_TEXT_UTF8_INPUT,
                    (text = "UTF-8 input", init = "日本語"))
            }
    }
}


// =============================================================================
// Images — cpp:1194-1276
// =============================================================================

def private ImagesSection() {
    tree_node(WIDGETS_IMAGES_SECTION,
        (text = "Images", flags = ImGuiTreeNodeFlags.None)) {

        let io & = unsafe(GetIO())
        text_wrapped((text = "Below we are displaying the font texture (which is the only texture " +
            "we have access to in this demo). Use the 'ImTextureID' type as " +
            "storage to pass pointers or identifier to your own texture data. " +
            "Hover the texture for a zoomed view!"))

        let my_tex_id = io.Fonts.TexID
        let my_tex_w = float(io.Fonts.TexWidth)
        let my_tex_h = float(io.Fonts.TexHeight)

        checkbox(WIDGETS_IMAGES_USE_TINT, (text = "Use Text Color for Tint"))
        text("{int(my_tex_w)}x{int(my_tex_h)}")
        let pos = GetCursorScreenPos()
        let uv_min = float2(0.0f, 0.0f)
        let uv_max = float2(1.0f, 1.0f)
        let tint_col = WIDGETS_IMAGES_USE_TINT.value \
            ? GetStyleColorVec4(ImGuiCol.Text) : float4(1.0f, 1.0f, 1.0f, 1.0f)
        let border_col = GetStyleColorVec4(ImGuiCol.Border)
        image((user_texture_id = my_tex_id,
               size = float2(my_tex_w, my_tex_h),
               uv0 = uv_min, uv1 = uv_max,
               tint_col = tint_col, border_col = border_col))
        // Hover-to-zoom tooltip — fancy contents, so item_tooltip container.
        item_tooltip(WIDGETS_IMAGES_ZOOM_TIP) {
            let region_sz = 32.0f
            var region_x = io.MousePos.x - pos.x - region_sz * 0.5f
            var region_y = io.MousePos.y - pos.y - region_sz * 0.5f
            let zoom = 4.0f
            if (region_x < 0.0f) {
                region_x = 0.0f
            } elif (region_x > my_tex_w - region_sz) {
                region_x = my_tex_w - region_sz
            }
            if (region_y < 0.0f) {
                region_y = 0.0f
            } elif (region_y > my_tex_h - region_sz) {
                region_y = my_tex_h - region_sz
            }
            text("Min: ({region_x}, {region_y})")
            text("Max: ({region_x + region_sz}, {region_y + region_sz})")
            let uv0 = float2(region_x / my_tex_w, region_y / my_tex_h)
            let uv1 = float2((region_x + region_sz) / my_tex_w,
                             (region_y + region_sz) / my_tex_h)
            image((user_texture_id = my_tex_id,
                   size = float2(region_sz * zoom, region_sz * zoom),
                   uv0 = uv0, uv1 = uv1,
                   tint_col = tint_col, border_col = border_col))
        }

        text_wrapped("And now some textured buttons..")
        for (i in range(8)) {
            // Per-iteration FramePadding push for i>0. `with_style` scopes the var.
            if (i > 0) {
                with_style((ImGuiStyleVar.FramePadding,
                            float2(float(i) - 1.0f, float(i) - 1.0f))) {
                    ImageBtnAt(i, my_tex_id, my_tex_w, my_tex_h)
                }
            } else {
                ImageBtnAt(i, my_tex_id, my_tex_w, my_tex_h)
            }
            same_line(WIDGETS_LOOP_IMG_SL[i])
        }
        new_line(WIDGETS_NL_1)
        text("Pressed {WIDGETS_IMAGES_PRESSED_COUNT} times.")
    }
}

// ImageButton helper for the 8-button loop. Wrapped in its own function so
// `with_style` can wrap a single call cleanly without an if/else split.
def private ImageBtnAt(i : int; tex_id : void?; tex_w, tex_h : float) {
    let size = float2(32.0f, 32.0f)
    let uv0 = float2(0.0f, 0.0f)
    let uv1 = float2(32.0f / tex_w, 32.0f / tex_h)
    let bg_col = float4(0.0f, 0.0f, 0.0f, 1.0f)
    let btn_tint = float4(1.0f, 1.0f, 1.0f, 1.0f)
    if (image_button(WIDGETS_IMAGES_BTN[i],
        (text = "", user_texture_id = tex_id, size = size,
         uv0 = uv0, uv1 = uv1, bg_col = bg_col, tint_col = btn_tint))) {
        WIDGETS_IMAGES_PRESSED_COUNT++
    }
}
