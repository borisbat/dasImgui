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
// Ported subsections:
//   Basic, Tooltips, Tree Nodes, Collapsing Headers, Bullets, Text, Images
//   (cpp:651-1276) + Tier-A quick-win subsections:
//   Combo (1279), List boxes (1347), Plotting (1898), Progress Bars (1961),
//   Range Widgets (2217), Multi-component (2352), Vertical Sliders (2385),
//   Disable block (2808), Text Filter (2816).
//
// Remaining stubs (Tier B/C/D): Selectables (7 trees), Text Input (6),
// Tabs (3), Drag and Drop (4), Color/Picker, Drag/Slider Flags, Data Types,
// Querying Item/Window Status.
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

// ----- Tier-A subsection state -----
// Combo: shared item list (cpp:1304) + ComboFlags via edit_checkbox_flags.
let private WIDGETS_COMBO_ITEMS : array<string> <- ["AAAA", "BBBB", "CCCC", "DDDD",
                                                    "EEEE", "FFFF", "GGGG", "HHHH",
                                                    "IIII", "JJJJ", "KKKK", "LLLLLLL",
                                                    "MMMM", "OOOOOOO"]
var private WIDGETS_COMBO_FLAGS = int(ImGuiComboFlags.None)
var private WIDGETS_COMBO_LB_ROW : table<int; ClickState>

// List Boxes: separate per-box row tables because every Selectable inside a
// container needs its own state global (path key disambiguation).
var private WIDGETS_LB_ROW1 : table<int; ClickState>
var private WIDGETS_LB_ROW2 : table<int; ClickState>

// Text Filter: per-line bullet idents (cpp:2828, 8 entries — kept generic).
var private WIDGETS_TF_LINE : table<int; NarrativeState>

// Plotting: animated values buffer (cpp:1912) + cosine-phase scratch.
var private WIDGETS_PLOT_VALUES : array<float>
var private WIDGETS_PLOT_VALUES_OFFSET = 0
var private WIDGETS_PLOT_REFRESH_TIME = 0.0lf
var private WIDGETS_PLOT_PHASE = 0.0f
let private WIDGETS_PLOT_FRAMETIMES : array<float> <- [0.6f, 0.1f, 1.0f, 0.5f,
                                                       0.92f, 0.1f, 0.2f]

// Progress Bars: animation state (cpp:1964); fraction wraps in [-0.1, 1.1].
var private WIDGETS_PROGRESS = 0.0f
var private WIDGETS_PROGRESS_DIR = 1.0f

// Vertical Sliders: three groups of state (cpp:2390 / 2394 / 2414).
//   *_INT_PTR / *_VALUES{,_2} are caller-owned data fed to edit_vslider_*;
//   *_SET{1,2,3} are per-iteration same_line markers (indexed); *_GROUP is
//   the per-column BeginGroup container; *_TIP{1,2} are per-iter tooltip
//   widgets (one fires per frame when an item is active/hovered).
var private WIDGETS_VS_INT_PTR = 0
var private WIDGETS_VS_VALUES : array<float> <- [0.0f, 0.60f, 0.35f, 0.9f,
                                                 0.70f, 0.20f, 0.0f]
var private WIDGETS_VS_VALUES2 : array<float> <- [0.20f, 0.80f, 0.40f, 0.25f]
var private WIDGETS_VS_SET1 : table<int; EmptyMarkerState>
var private WIDGETS_VS_SET2 : table<int; EmptyMarkerState>
var private WIDGETS_VS_SET3 : table<int; EmptyMarkerState>
var private WIDGETS_VS_GROUP : table<int; GroupState>
var private WIDGETS_VS_TIP1 : table<int; NarrativeState>
var private WIDGETS_VS_TIP2 : table<int; NarrativeState>


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
                ComboSection()
                ListBoxesSection()
                PlottingSection()
                ProgressBarsSection()
                RangeWidgetsSection()
                MultiComponentSection()
                VerticalSlidersSection()
            }
            // "Disable block" exposes the WIDGETS_DISABLE_ALL checkbox itself;
            // it would be hidden by its own gate inside with_disabled, so it
            // sits OUTSIDE the with_disabled scope (matches cpp:2807 placement
            // after the with_disabled-equivalent block).
            DisableBlockSection()
            TextFilterSection()
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


// =============================================================================
// Combo — cpp:1279-1344
// =============================================================================

def private ComboSection() {
    tree_node(WIDGETS_COMBO_SECTION,
        (text = "Combo", flags = ImGuiTreeNodeFlags.None)) {

        text("Combo Boxes are also called \"Dropdown\" in other systems.")

        edit_checkbox_flags(safe_addr(WIDGETS_COMBO_FLAGS),
            (id = "WIDGETS_COMBO_F_POPUP_LEFT",
             text = "ImGuiComboFlags_PopupAlignLeft",
             flags_value = int(ImGuiComboFlags.PopupAlignLeft)))
        same_line(WIDGETS_COMBO_SL_1)
        text_disabled("(?)")
        item_tooltip(WIDGETS_COMBO_HM_LEFT) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted("Only makes a difference if the popup is larger than the combo.")
            }
        }

        // NoArrowButton / NoPreview / WidthFitPreview are mutually exclusive
        // pairs; clearing the incompatible flag matches cpp:1287-1291.
        if (edit_checkbox_flags(safe_addr(WIDGETS_COMBO_FLAGS),
            (id = "WIDGETS_COMBO_F_NO_ARROW",
             text = "ImGuiComboFlags_NoArrowButton",
             flags_value = int(ImGuiComboFlags.NoArrowButton)))) {
            WIDGETS_COMBO_FLAGS &= ~int(ImGuiComboFlags.NoPreview)
        }
        if (edit_checkbox_flags(safe_addr(WIDGETS_COMBO_FLAGS),
            (id = "WIDGETS_COMBO_F_NO_PREVIEW",
             text = "ImGuiComboFlags_NoPreview",
             flags_value = int(ImGuiComboFlags.NoPreview)))) {
            WIDGETS_COMBO_FLAGS &= ~int(ImGuiComboFlags.NoArrowButton |
                                        ImGuiComboFlags.WidthFitPreview)
        }
        if (edit_checkbox_flags(safe_addr(WIDGETS_COMBO_FLAGS),
            (id = "WIDGETS_COMBO_F_WIDTH_FIT",
             text = "ImGuiComboFlags_WidthFitPreview",
             flags_value = int(ImGuiComboFlags.WidthFitPreview)))) {
            WIDGETS_COMBO_FLAGS &= ~int(ImGuiComboFlags.NoPreview)
        }

        // Height presets — clearing the rest of HeightMask_ matches cpp:1295-1299.
        let HEIGHT_MASK = int(ImGuiComboFlags.HeightMask_)
        if (edit_checkbox_flags(safe_addr(WIDGETS_COMBO_FLAGS),
            (id = "WIDGETS_COMBO_F_HEIGHT_S",
             text = "ImGuiComboFlags_HeightSmall",
             flags_value = int(ImGuiComboFlags.HeightSmall)))) {
            WIDGETS_COMBO_FLAGS &= ~(HEIGHT_MASK & ~int(ImGuiComboFlags.HeightSmall))
        }
        if (edit_checkbox_flags(safe_addr(WIDGETS_COMBO_FLAGS),
            (id = "WIDGETS_COMBO_F_HEIGHT_R",
             text = "ImGuiComboFlags_HeightRegular",
             flags_value = int(ImGuiComboFlags.HeightRegular)))) {
            WIDGETS_COMBO_FLAGS &= ~(HEIGHT_MASK & ~int(ImGuiComboFlags.HeightRegular))
        }
        if (edit_checkbox_flags(safe_addr(WIDGETS_COMBO_FLAGS),
            (id = "WIDGETS_COMBO_F_HEIGHT_L",
             text = "ImGuiComboFlags_HeightLargest",
             flags_value = int(ImGuiComboFlags.HeightLargest)))) {
            WIDGETS_COMBO_FLAGS &= ~(HEIGHT_MASK & ~int(ImGuiComboFlags.HeightLargest))
        }

        // combo 1 — BeginCombo + manual Selectable loop via combo_select.
        // Preview value reads from WIDGETS_COMBO_C1.value (index into shared items).
        let combo_flags = unsafe(reinterpret<ImGuiComboFlags>(WIDGETS_COMBO_FLAGS))
        let preview_idx = WIDGETS_COMBO_C1.value
        let preview = ((preview_idx >= 0 && preview_idx < length(WIDGETS_COMBO_ITEMS))
            ? WIDGETS_COMBO_ITEMS[preview_idx] : "")
        combo_select(WIDGETS_COMBO_C1,
            (text = "combo 1", preview_value = preview, flags = combo_flags)) {
            for (n in range(length(WIDGETS_COMBO_ITEMS))) {
                let is_selected = (WIDGETS_COMBO_C1.value == n)
                if (selectable_label(WIDGETS_COMBO_LB_ROW[n],
                                     WIDGETS_COMBO_ITEMS[n], is_selected)) {
                    WIDGETS_COMBO_C1.value = n
                }
                if (is_selected) {
                    SetItemDefaultFocus()
                }
            }
        }

        spacing(WIDGETS_COMBO_SPACING)
        separator_text(WIDGETS_COMBO_SEP, "One-liner variants")
        text_disabled("(?)")
        item_tooltip(WIDGETS_COMBO_HM_ONELINE) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted("Flags above don't apply to this section.")
            }
        }

        // combo 2 — one-liner; cpp packs into "aaaa\0bbbb\0..."; boost combo
        // takes array<string> and packs the same null-separated buffer internally.
        combo(WIDGETS_COMBO_C2,
            (text = "combo 2 (one-liner)",
             items <- ["aaaa", "bbbb", "cccc", "dddd", "eeee"]))

        // combo 3 — array form sharing the full 14-item list. cpp starts at
        // -1 so no preview shows initially; daslang state defaults to 0, so we
        // skip the negative-start trick (visual difference is minor).
        combo(WIDGETS_COMBO_C3,
            (text = "combo 3 (array)", items <- WIDGETS_COMBO_ITEMS))

        // combo 4 — getter form. The thunk indexes into the shared items list.
        combo_getter(WIDGETS_COMBO_C4,
            (text = "combo 4 (function)",
             items_count = length(WIDGETS_COMBO_ITEMS),
             getter = @(idx : int; var result : string&) : bool {
                if (idx >= 0 && idx < length(WIDGETS_COMBO_ITEMS)) {
                    result = WIDGETS_COMBO_ITEMS[idx]
                    return true
                }
                return false
             }))
    }
}


// =============================================================================
// List boxes — cpp:1347-1393
// =============================================================================

def private ListBoxesSection() {
    tree_node(WIDGETS_LB_SECTION,
        (text = "List boxes", flags = ImGuiTreeNodeFlags.None)) {

        // Two list_box instances SHARE one selection state (cpp:1358) — both
        // read/write WIDGETS_LB_SHARED.value. The (-1, 0) default-size form
        // wraps the items list snugly; the second box overrides size to take
        // full content width and 5 rows tall.
        list_box(WIDGETS_LB_SHARED,
            (text = "listbox 1", size = float2(0.0f, 0.0f))) {
            for (n in range(length(WIDGETS_COMBO_ITEMS))) {
                let is_selected = (WIDGETS_LB_SHARED.value == n)
                if (selectable_label(WIDGETS_LB_ROW1[n],
                                     WIDGETS_COMBO_ITEMS[n], is_selected)) {
                    WIDGETS_LB_SHARED.value = n
                }
                if (is_selected) {
                    SetItemDefaultFocus()
                }
            }
        }
        same_line(WIDGETS_LB_SL_HINT)
        text_disabled("(?)")
        item_tooltip(WIDGETS_LB_HM_SHARE) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted("Here we are sharing selection state between both boxes.")
            }
        }

        text("Full-width:")
        let full_h = 5.0f * GetTextLineHeightWithSpacing()
        list_box(WIDGETS_LB_FULL,
            (text = "##listbox 2", size = float2(-1.0f, full_h))) {
            for (n in range(length(WIDGETS_COMBO_ITEMS))) {
                let is_selected = (WIDGETS_LB_SHARED.value == n)
                if (selectable_label(WIDGETS_LB_ROW2[n],
                                     WIDGETS_COMBO_ITEMS[n], is_selected)) {
                    WIDGETS_LB_SHARED.value = n
                }
                if (is_selected) {
                    SetItemDefaultFocus()
                }
            }
        }
    }
}


// =============================================================================
// Plotting — cpp:1898-1958
// =============================================================================

def private PlottingSection() {
    tree_node(WIDGETS_PLOT_SECTION,
        (text = "Plotting", flags = ImGuiTreeNodeFlags.None)) {

        checkbox(WIDGETS_PLOT_ANIMATE, (text = "Animate", init = true))

        // Frame-times array (7 values) — plot as lines AND histogram.
        plot_lines(WIDGETS_PLOT_FRAMETIMES_LINES,
            (text = "Frame Times", values <- WIDGETS_PLOT_FRAMETIMES))
        plot_histogram(WIDGETS_PLOT_FRAMETIMES_HIST,
            (text = "Histogram", values <- WIDGETS_PLOT_FRAMETIMES,
             scale_min = 0.0f, scale_max = 1.0f,
             graph_size = float2(0.0f, 80.0f)))

        // 90-sample rolling cosine buffer animated at fixed 60 Hz to decouple
        // from the recorder/host frame rate (cpp:1912-1924).
        if (length(WIDGETS_PLOT_VALUES) != 90) {
            WIDGETS_PLOT_VALUES |> resize(90)
        }
        let now = GetTime()
        if (!WIDGETS_PLOT_ANIMATE.value || WIDGETS_PLOT_REFRESH_TIME == 0.0lf) {
            WIDGETS_PLOT_REFRESH_TIME = now
        }
        while (WIDGETS_PLOT_REFRESH_TIME < now) {
            WIDGETS_PLOT_VALUES[WIDGETS_PLOT_VALUES_OFFSET] = cos(WIDGETS_PLOT_PHASE)
            WIDGETS_PLOT_VALUES_OFFSET = (WIDGETS_PLOT_VALUES_OFFSET + 1) % 90
            WIDGETS_PLOT_PHASE += 0.10f * float(WIDGETS_PLOT_VALUES_OFFSET)
            WIDGETS_PLOT_REFRESH_TIME += 1.0lf / 60.0lf
        }

        // Average overlay — cpp:1929-1935.
        var average = 0.0f
        for (v in WIDGETS_PLOT_VALUES) {
            average += v
        }
        average /= float(length(WIDGETS_PLOT_VALUES))
        plot_lines(WIDGETS_PLOT_LINES,
            (text = "Lines", values <- WIDGETS_PLOT_VALUES,
             scale_min = -1.0f, scale_max = 1.0f,
             graph_size = float2(0.0f, 80.0f)))
        // plot_lines binding takes the array as-is — no values_offset rotation
        // arg (the cpp passes the offset to skip the head; our boost wrapper
        // currently always starts at index 0). Behaviorally the wave still
        // animates correctly; only the "rolling head" alignment differs.
        text("avg {average}")

        // Sin / Saw lambda-driven plots via *_getter (cpp:1941-1954).
        separator_text(WIDGETS_PLOT_SEP_FUNC, "Functions")
        with_item_width(GetFontSize() * 8.0f) {
            combo(WIDGETS_PLOT_FUNC, (text = "func", items <- ["Sin", "Saw"]))
        }
        same_line(WIDGETS_PLOT_SL_FUNC)
        slider_int(WIDGETS_PLOT_SAMPLE_COUNT,
            (text = "Sample count", init = 70, bounds = (1, 400)))

        let is_sin = (WIDGETS_PLOT_FUNC.value == 0)
        let count = WIDGETS_PLOT_SAMPLE_COUNT.value
        plot_lines_getter(WIDGETS_PLOT_LINES_FN,
            (text = "Lines", values_count = count,
             getter = @(idx : int) : float => is_sin
                ? sin(float(idx) * 0.1f)
                : (((idx & 1) != 0) ? 1.0f : -1.0f),
             overlay_text = "",
             scale_min = -1.0f, scale_max = 1.0f,
             graph_size = float2(0.0f, 80.0f)))
        plot_histogram_getter(WIDGETS_PLOT_HIST_FN,
            (text = "Histogram", values_count = count,
             getter = @(idx : int) : float => is_sin
                ? sin(float(idx) * 0.1f)
                : (((idx & 1) != 0) ? 1.0f : -1.0f),
             overlay_text = "",
             scale_min = -1.0f, scale_max = 1.0f,
             graph_size = float2(0.0f, 80.0f)))
        separator(WIDGETS_PLOT_SEP)
    }
}


// =============================================================================
// Progress Bars — cpp:1961-1987
// =============================================================================

def private ProgressBarsSection() {
    tree_node(WIDGETS_PB_SECTION,
        (text = "Progress Bars", flags = ImGuiTreeNodeFlags.None)) {

        // Ping-pong progress in [-0.1, 1.1] driven by frame delta-time.
        let io & = unsafe(GetIO())
        WIDGETS_PROGRESS += WIDGETS_PROGRESS_DIR * 0.4f * io.DeltaTime
        if (WIDGETS_PROGRESS >= 1.1f) {
            WIDGETS_PROGRESS = 1.1f
            WIDGETS_PROGRESS_DIR *= -1.0f
        }
        if (WIDGETS_PROGRESS <= -0.1f) {
            WIDGETS_PROGRESS = -0.1f
            WIDGETS_PROGRESS_DIR *= -1.0f
        }

        progress_bar(WIDGETS_PB_DEFAULT,
            (fraction = WIDGETS_PROGRESS, size = float2(0.0f, 0.0f)))
        same_line((offset_from_start_x = 0.0f,
                   spacing = GetStyle().ItemInnerSpacing.x))
        text("Progress Bar")

        let saturated = clamp(WIDGETS_PROGRESS, 0.0f, 1.0f)
        let units = int(saturated * 1753.0f)
        progress_bar(WIDGETS_PB_OVERLAY,
            (fraction = WIDGETS_PROGRESS, size = float2(0.0f, 0.0f),
             overlay = "{units}/1753"))

        // Negative fraction renders an indeterminate animation. -GetTime()
        // pumps a continuously-decreasing value so ImGui advances its phase.
        progress_bar(WIDGETS_PB_INDETERMINATE,
            (fraction = -1.0f * float(GetTime()),
             size = float2(0.0f, 0.0f),
             overlay = "Searching.."))
        same_line((offset_from_start_x = 0.0f,
                   spacing = GetStyle().ItemInnerSpacing.x))
        text("Indeterminate")
    }
}


// =============================================================================
// Range Widgets — cpp:2217-2225
// =============================================================================

def private RangeWidgetsSection() {
    tree_node(WIDGETS_RANGE_SECTION,
        (text = "Range Widgets", flags = ImGuiTreeNodeFlags.None)) {

        drag_float_range2(WIDGETS_RANGE_F,
            (text = "range float",
             init = float2(10.0f, 90.0f),
             bounds = (0.0f, 100.0f),
             speed = 0.25f,
             format = "%.1f %%",
             flags = ImGuiSliderFlags.AlwaysClamp))
        // Format-per-handle: cpp passes "Min: %.1f %%" / "Max: %.1f %%" but our
        // boost binding takes a single shared format string. Functional shape
        // (clamped range, draggable handles) matches; the per-handle label
        // prefix is a binding gap, not a behavior gap.
        drag_int_range2(WIDGETS_RANGE_I,
            (text = "range int",
             init = int2(100, 1000),
             bounds = (0, 1000),
             speed = 5.0f,
             format = "%d units"))
        drag_int_range2(WIDGETS_RANGE_I_NB,
            (text = "range int (no bounds)",
             init = int2(100, 1000),
             bounds = (0, 0),
             speed = 5.0f,
             format = "%d units"))
    }
}


// =============================================================================
// Multi-component Widgets — cpp:2352-2382
// =============================================================================
//
// cpp uses a single shared `vec4f[4]` / `vec4i[4]` for all 18 widgets; our
// boost rail auto-emits independent state per widget. Each widget shows the
// daslang form of its cpp counterpart, but values do not propagate between
// widgets (semantic deviation noted; cleaner than `safe_addr` arithmetic on
// a global). Initial values seeded with the cpp tuples for visual parity.

def private MultiComponentSection() {
    tree_node(WIDGETS_MC_SECTION,
        (text = "Multi-component Widgets", flags = ImGuiTreeNodeFlags.None)) {

        separator_text(WIDGETS_MC_SEP_2, "2-wide")
        input_float2(WIDGETS_MC_IF2, (text = "input float2",
                                      init = float2(0.10f, 0.20f)))
        drag_float2(WIDGETS_MC_DF2, (text = "drag float2",
                                     init = float2(0.10f, 0.20f),
                                     bounds = (0.0f, 1.0f), speed = 0.01f))
        slider_float2(WIDGETS_MC_SF2, (text = "slider float2",
                                       init = float2(0.10f, 0.20f),
                                       bounds = (0.0f, 1.0f)))
        input_int2(WIDGETS_MC_II2, (text = "input int2",
                                    init = int2(1, 5)))
        drag_int2(WIDGETS_MC_DI2, (text = "drag int2",
                                   init = int2(1, 5),
                                   bounds = (0, 255), speed = 1.0f))
        slider_int2(WIDGETS_MC_SI2, (text = "slider int2",
                                     init = int2(1, 5),
                                     bounds = (0, 255)))

        separator_text(WIDGETS_MC_SEP_3, "3-wide")
        input_float3(WIDGETS_MC_IF3, (text = "input float3",
                                      init = float3(0.10f, 0.20f, 0.30f)))
        drag_float3(WIDGETS_MC_DF3, (text = "drag float3",
                                     init = float3(0.10f, 0.20f, 0.30f),
                                     bounds = (0.0f, 1.0f), speed = 0.01f))
        slider_float3(WIDGETS_MC_SF3, (text = "slider float3",
                                       init = float3(0.10f, 0.20f, 0.30f),
                                       bounds = (0.0f, 1.0f)))
        input_int3(WIDGETS_MC_II3, (text = "input int3",
                                    init = int3(1, 5, 100)))
        drag_int3(WIDGETS_MC_DI3, (text = "drag int3",
                                   init = int3(1, 5, 100),
                                   bounds = (0, 255), speed = 1.0f))
        slider_int3(WIDGETS_MC_SI3, (text = "slider int3",
                                     init = int3(1, 5, 100),
                                     bounds = (0, 255)))

        separator_text(WIDGETS_MC_SEP_4, "4-wide")
        input_float4(WIDGETS_MC_IF4, (text = "input float4",
                                      init = float4(0.10f, 0.20f, 0.30f, 0.44f)))
        drag_float4(WIDGETS_MC_DF4, (text = "drag float4",
                                     init = float4(0.10f, 0.20f, 0.30f, 0.44f),
                                     bounds = (0.0f, 1.0f), speed = 0.01f))
        slider_float4(WIDGETS_MC_SF4, (text = "slider float4",
                                       init = float4(0.10f, 0.20f, 0.30f, 0.44f),
                                       bounds = (0.0f, 1.0f)))
        input_int4(WIDGETS_MC_II4, (text = "input int4",
                                    init = int4(1, 5, 100, 255)))
        drag_int4(WIDGETS_MC_DI4, (text = "drag int4",
                                   init = int4(1, 5, 100, 255),
                                   bounds = (0, 255), speed = 1.0f))
        slider_int4(WIDGETS_MC_SI4, (text = "slider int4",
                                     init = int4(1, 5, 100, 255),
                                     bounds = (0, 255)))
    }
}


// =============================================================================
// Vertical Sliders — cpp:2385-2447
// =============================================================================

def private VerticalSlidersSection() {
    tree_node(WIDGETS_VS_SECTION,
        (text = "Vertical Sliders", flags = ImGuiTreeNodeFlags.None)) {

        let spacing_px = 4.0f
        with_style((ImGuiStyleVar.ItemSpacing, float2(spacing_px, spacing_px))) {
            // Single VSliderInt + a row of 7 colored VSliderFloats sharing
            // WIDGETS_VS_VALUES (cpp:2390-2410). edit_vslider_* binds to the
            // caller-owned slot so each row stays "live" data, like cpp's
            // shared `values[]`. `with_id` carves the per-iteration ID scope.
            edit_vslider_int(safe_addr(WIDGETS_VS_INT_PTR),
                (id = "WIDGETS_VS_INT", text = "##int",
                 size = float2(18.0f, 160.0f), v_min = 0, v_max = 5))
            same_line(WIDGETS_VS_SL_AFTER_INT)

            with_id("set1") {
                for (i in range(7)) {
                    if (i > 0) {
                        same_line(WIDGETS_VS_SET1[i])
                    }
                    with_id("i_{i}") {
                        let hue = float(i) / 7.0f
                        with_style((ImGuiCol.FrameBg,        HSV(hue, 0.5f, 0.5f)),
                                   (ImGuiCol.FrameBgHovered, HSV(hue, 0.6f, 0.5f)),
                                   (ImGuiCol.FrameBgActive,  HSV(hue, 0.7f, 0.5f)),
                                   (ImGuiCol.SliderGrab,     HSV(hue, 0.9f, 0.9f))) {
                            VSlider1At(i)
                        }
                    }
                }
            }
            same_line(WIDGETS_VS_SL_SET1_END)

            // 4×3 grid of small vertical sliders (cpp:2414-2430). Each column
            // shares one float (values2[nx]) across 3 rows.
            with_id("set2") {
                let rows = 3
                let row_h = (160.0f - float(rows - 1) * spacing_px) / float(rows)
                let small_size = float2(18.0f, row_h)
                for (nx in range(4)) {
                    if (nx > 0) {
                        same_line(WIDGETS_VS_SET2[nx])
                    }
                    group(WIDGETS_VS_GROUP[nx]) {
                        with_id("col_{nx}") {
                            for (ny in range(rows)) {
                                with_id("row_{ny}") {
                                    VSlider2At(nx, small_size)
                                }
                            }
                        }
                    }
                }
            }
            same_line(WIDGETS_VS_SL_SET2_END)

            // Row of 4 fat-grab sliders reusing WIDGETS_VS_VALUES[0..3]
            // (cpp:2434-2444). GrabMinSize style var scoped per slider.
            with_id("set3") {
                for (i in range(4)) {
                    if (i > 0) {
                        same_line(WIDGETS_VS_SET3[i])
                    }
                    with_id("i_{i}") {
                        with_style((ImGuiStyleVar.GrabMinSize, 40.0f)) {
                            VSlider3At(i)
                        }
                    }
                }
            }
        }
    }
}

// Per-iteration VSliderFloat helpers — wrapped so `with_style` can scope a
// single statement cleanly. All three bind to slices of the shared arrays
// via edit_vslider_float; tooltip-on-active mirrors cpp:2405-2406 (2425-26).
def private VSlider1At(i : int) {
    edit_vslider_float(unsafe(addr(WIDGETS_VS_VALUES[i])),
        (id = "WIDGETS_VS_SLIDER1", text = "##v",
         size = float2(18.0f, 160.0f),
         v_min = 0.0f, v_max = 1.0f, format = ""))
    if (IsItemActive() || IsItemHovered()) {
        set_tooltip(WIDGETS_VS_TIP1[i], "{WIDGETS_VS_VALUES[i]}")
    }
}

def private VSlider2At(nx : int; size : float2) {
    edit_vslider_float(unsafe(addr(WIDGETS_VS_VALUES2[nx])),
        (id = "WIDGETS_VS_SLIDER2", text = "##v",
         size = size, v_min = 0.0f, v_max = 1.0f, format = ""))
    if (IsItemActive() || IsItemHovered()) {
        set_tooltip(WIDGETS_VS_TIP2[nx], "{WIDGETS_VS_VALUES2[nx]}")
    }
}

def private VSlider3At(i : int) {
    edit_vslider_float(unsafe(addr(WIDGETS_VS_VALUES[i])),
        (id = "WIDGETS_VS_SLIDER3", text = "##v",
         size = float2(40.0f, 160.0f),
         v_min = 0.0f, v_max = 1.0f, format = "%.2f\nsec"))
}


// =============================================================================
// Disable block — cpp:2807-2813
// =============================================================================
//
// The checkbox toggles WIDGETS_DISABLE_ALL, the same plain var that gates
// `with_disabled` around the rest of the Widgets sections. Lives OUTSIDE
// with_disabled so it stays interactive even when everything else is
// disabled (matches cpp's EndDisabled-before-TreeNode placement).

def private DisableBlockSection() {
    tree_node(WIDGETS_DIS_SECTION,
        (text = "Disable block", flags = ImGuiTreeNodeFlags.None)) {

        edit_checkbox(safe_addr(WIDGETS_DISABLE_ALL),
            (id = "WIDGETS_DIS_CB", text = "Disable entire section above"))
        same_line(WIDGETS_DIS_SL)
        text_disabled("(?)")
        item_tooltip(WIDGETS_DIS_HM) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted("Demonstrate using BeginDisabled()/EndDisabled() across this section.")
            }
        }
    }
}


// =============================================================================
// Text Filter — cpp:2816-2832
// =============================================================================

def private TextFilterSection() {
    tree_node(WIDGETS_TF_SECTION,
        (text = "Text Filter", flags = ImGuiTreeNodeFlags.None)) {

        text_disabled("(?)")
        item_tooltip(WIDGETS_TF_HM) {
            with_text_wrap_pos(GetFontSize() * 35.0f) {
                text_unformatted("Not a widget per-se, but ImGuiTextFilter is a helper to perform simple filtering on text strings.")
            }
        }

        text_unformatted((text = "Filter usage:\n" +
            "  \"\"         display all lines\n" +
            "  \"xxx\"      display lines containing \"xxx\"\n" +
            "  \"xxx,yyy\"  display lines containing \"xxx\" or \"yyy\"\n" +
            "  \"-xxx\"     hide lines containing \"xxx\""))

        text_filter(WIDGETS_TF_FILTER,
            (text = "Filter (\"incl,-excl\") (\"error\")"))

        // Bullet each line that survives the filter. Lines are hard-coded
        // per cpp:2828 — the boost wrapper reads passes_filter(state, line).
        let lines <- ["aaa1.c", "bbb1.c", "ccc1.c", "aaa2.cpp",
                      "bbb2.cpp", "ccc2.cpp", "abc.h", "hello, world"]
        for (i in range(length(lines))) {
            if (passes_filter(WIDGETS_TF_FILTER, lines[i])) {
                bullet_text(WIDGETS_TF_LINE[i], (text = lines[i]))
            }
        }
    }
}
