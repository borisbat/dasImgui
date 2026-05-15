options gen2
options indenting = 4

module style_editor

require imgui
require imgui/imgui_widgets_builtin
require imgui/imgui_containers_builtin
require imgui/imgui_scope_builtin
require imgui/imgui_id_builtin
require daslib/enum_trait

// Mirrors imgui_demo.cpp:6680-6962 — void ImGui::ShowStyleEditor(ImGuiStyle* ref).
//
// Scope notes for the daslang port:
//   - This function does NOT open its own window; the caller is expected to
//     wrap it in a Begin/End (or boost `window(...)`). Same shape as C++.
//   - All sliders here edit fields of ImGui's live style struct via the
//     boost-v2 `edit_*` rail (caller-owned `T?` pointer). `safe_addr` is
//     local-var-only and rejects struct-field-via-reference lvalues, so we
//     use `unsafe(addr(style.X))` to take the address of each field.
//   - Skipped vs C++ (each cited at the relevant location below):
//       - SliderFloat2 / SliderAngle on style.<float2 fields> (need
//         reinterpret + bounce-buffer; pending Phase 3)
//       - CheckboxFlags TreeNodeEx block for HoverFlagsForTooltipMouse/Nav
//         (enum-typed flags need a bounce-buffer; pending Phase 3)
//       - "Save Ref" / "Revert Ref" buttons (ref-style param is null in this
//         demo; the buttons are a no-op without it)
//       - Colors tab: Export-to-clipboard + Filter + alpha-flags radios
//         (cpp:6798-6831; needs ImGuiTextFilter binding + bounce-buffer)
//       - Fonts tab: ShowFontAtlas + window-scoped font-scale slider
//         (cpp:6872 + 6885; debug helper + private window state)
//       - Rendering tab: Circle Tessellation preview tooltip
//         (cpp:6909-6947; uses private _CalcCircleAutoSegmentCount API)
def ShowStyleEditor() {
    var style & = unsafe(GetStyle())

    with_item_width(GetWindowWidth() * 0.50f) {
        // Built-in style/font pickers.
        if (ShowStyleSelector("Colors##Selector")) {}
        ShowFontSelector("Fonts##Selector")

        // "Simplified Settings": one float slider editing style.FrameRounding.
        if (edit_slider_float(unsafe(addr(style.FrameRounding)),
                              (id = "STYLE_FRAME_ROUNDING",
                               text = "FrameRounding",
                               v_min = 0.0f, v_max = 12.0f,
                               format = "%.0f"))) {
            // C++ keeps GrabRounding == FrameRounding for visual consistency.
            style.GrabRounding = style.FrameRounding
        }

        Separator()

        tab_bar(STYLE_TABS, (text = "##tabs", flags = ImGuiTabBarFlags.None)) {
            tab_item(STYLE_TAB_SIZES, (text = "Sizes", closable = false,
                                       flags = ImGuiTabItemFlags.None)) {
                SeparatorText("Main")
                // SliderFloat2 calls on WindowPadding/FramePadding/ItemSpacing/
                // ItemInnerSpacing/TouchExtraPadding skipped pending Phase 3.
                // See imgui_demo.cpp:6729-6733.
                edit_slider_float(unsafe(addr(style.IndentSpacing)),
                                  (id = "STYLE_INDENT_SPACING",
                                   text = "IndentSpacing",
                                   v_min = 0.0f, v_max = 30.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.ScrollbarSize)),
                                  (id = "STYLE_SCROLLBAR_SIZE",
                                   text = "ScrollbarSize",
                                   v_min = 1.0f, v_max = 20.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.GrabMinSize)),
                                  (id = "STYLE_GRAB_MIN_SIZE",
                                   text = "GrabMinSize",
                                   v_min = 1.0f, v_max = 20.0f, format = "%.0f"))

                SeparatorText("Borders")
                edit_slider_float(unsafe(addr(style.WindowBorderSize)),
                                  (id = "STYLE_WINDOW_BORDER_SIZE",
                                   text = "WindowBorderSize",
                                   v_min = 0.0f, v_max = 1.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.ChildBorderSize)),
                                  (id = "STYLE_CHILD_BORDER_SIZE",
                                   text = "ChildBorderSize",
                                   v_min = 0.0f, v_max = 1.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.PopupBorderSize)),
                                  (id = "STYLE_POPUP_BORDER_SIZE",
                                   text = "PopupBorderSize",
                                   v_min = 0.0f, v_max = 1.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.FrameBorderSize)),
                                  (id = "STYLE_FRAME_BORDER_SIZE",
                                   text = "FrameBorderSize",
                                   v_min = 0.0f, v_max = 1.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.TabBorderSize)),
                                  (id = "STYLE_TAB_BORDER_SIZE",
                                   text = "TabBorderSize",
                                   v_min = 0.0f, v_max = 1.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.TabBarBorderSize)),
                                  (id = "STYLE_TAB_BAR_BORDER_SIZE",
                                   text = "TabBarBorderSize",
                                   v_min = 0.0f, v_max = 2.0f, format = "%.0f"))

                SeparatorText("Rounding")
                edit_slider_float(unsafe(addr(style.WindowRounding)),
                                  (id = "STYLE_WINDOW_ROUNDING",
                                   text = "WindowRounding",
                                   v_min = 0.0f, v_max = 12.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.ChildRounding)),
                                  (id = "STYLE_CHILD_ROUNDING",
                                   text = "ChildRounding",
                                   v_min = 0.0f, v_max = 12.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.PopupRounding)),
                                  (id = "STYLE_POPUP_ROUNDING",
                                   text = "PopupRounding",
                                   v_min = 0.0f, v_max = 12.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.ScrollbarRounding)),
                                  (id = "STYLE_SCROLLBAR_ROUNDING",
                                   text = "ScrollbarRounding",
                                   v_min = 0.0f, v_max = 12.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.GrabRounding)),
                                  (id = "STYLE_GRAB_ROUNDING",
                                   text = "GrabRounding",
                                   v_min = 0.0f, v_max = 12.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.TabRounding)),
                                  (id = "STYLE_TAB_ROUNDING",
                                   text = "TabRounding",
                                   v_min = 0.0f, v_max = 12.0f, format = "%.0f"))

                SeparatorText("Misc")
                edit_slider_float(unsafe(addr(style.SeparatorTextBorderSize)),
                                  (id = "STYLE_SEPARATOR_TEXT_BORDER_SIZE",
                                   text = "SeparatorTextBorderSize",
                                   v_min = 0.0f, v_max = 10.0f, format = "%.0f"))
                edit_slider_float(unsafe(addr(style.LogSliderDeadzone)),
                                  (id = "STYLE_LOG_SLIDER_DEADZONE",
                                   text = "LogSliderDeadzone",
                                   v_min = 0.0f, v_max = 12.0f, format = "%.0f"))

                SeparatorText("Docking")
                edit_slider_float(unsafe(addr(style.DockingSeparatorSize)),
                                  (id = "STYLE_DOCKING_SPLITTER_SIZE",
                                   text = "DockingSplitterSize",
                                   v_min = 0.0f, v_max = 12.0f, format = "%.0f"))
            }

            tab_item(STYLE_TAB_COLORS, (text = "Colors", closable = false,
                                        flags = ImGuiTabItemFlags.None)) {
                // Stripped-down color editor: one ColorEdit4 per ImGuiCol entry.
                // Skipped vs C++: filter widget, export-to-clipboard, alpha-mode
                // radio group, and per-color Save/Revert buttons (see file-level
                // doc comment).
                child(STYLE_COLORS_CHILD,
                      (text = "##colors", size = float2(0.0f, 0.0f),
                       child_flags = ImGuiChildFlags.Border,
                       window_flags = ImGuiWindowFlags.AlwaysVerticalScrollbar)) {
                    with_item_width(GetFontSize() * -12.0f) {
                        for (col in type<ImGuiCol>) {
                            if (col == ImGuiCol.COUNT) continue
                            let name = GetStyleColorName(col)
                            with_id("row_{int(col)}") {
                                edit_color_edit4(
                                    unsafe(addr(style.Colors[int(col)])),
                                    (id = "COLOR", text = "##color",
                                     flags = ImGuiColorEditFlags.AlphaBar))
                                SameLine(0.0f, style.ItemInnerSpacing.x)
                                TextUnformatted(name)
                            }
                        }
                    }
                }
            }

            tab_item(STYLE_TAB_FONTS, (text = "Fonts", closable = false,
                                       flags = ImGuiTabItemFlags.None)) {
                // ShowFontAtlas (cpp:6872) skipped — debug helper.
                // Window-scoped font scale (cpp:6885) skipped — needs window state.
                var io & = unsafe(GetIO())
                edit_drag_float(unsafe(addr(io.FontGlobalScale)),
                                (id = "STYLE_FONT_GLOBAL_SCALE",
                                 text = "global scale",
                                 speed = 0.005f, v_min = 0.3f, v_max = 2.0f,
                                 format = "%.2f",
                                 flags = ImGuiSliderFlags.AlwaysClamp))
            }

            tab_item(STYLE_TAB_RENDERING, (text = "Rendering", closable = false,
                                           flags = ImGuiTabItemFlags.None)) {
                edit_checkbox(unsafe(addr(style.AntiAliasedLines)),
                              (id = "STYLE_AA_LINES",
                               text = "Anti-aliased lines"))
                edit_checkbox(unsafe(addr(style.AntiAliasedLinesUseTex)),
                              (id = "STYLE_AA_LINES_USE_TEX",
                               text = "Anti-aliased lines use texture"))
                edit_checkbox(unsafe(addr(style.AntiAliasedFill)),
                              (id = "STYLE_AA_FILL",
                               text = "Anti-aliased fill"))
                edit_drag_float(unsafe(addr(style.CurveTessellationTol)),
                                (id = "STYLE_CURVE_TESS_TOL",
                                 text = "Curve Tessellation Tolerance",
                                 speed = 0.02f, v_min = 0.10f, v_max = 10.0f,
                                 format = "%.2f"))
                if (style.CurveTessellationTol < 0.10f) {
                    style.CurveTessellationTol = 0.10f
                }
                // Circle Tessellation preview tooltip (cpp:6909-6947) skipped.
                edit_drag_float(unsafe(addr(style.CircleTessellationMaxError)),
                                (id = "STYLE_CIRCLE_TESS_MAX_ERROR",
                                 text = "Circle Tessellation Max Error",
                                 speed = 0.005f, v_min = 0.10f, v_max = 5.0f,
                                 format = "%.2f",
                                 flags = ImGuiSliderFlags.AlwaysClamp))
                edit_drag_float(unsafe(addr(style.Alpha)),
                                (id = "STYLE_ALPHA",
                                 text = "Global Alpha",
                                 speed = 0.005f, v_min = 0.20f, v_max = 1.0f,
                                 format = "%.2f"))
                edit_drag_float(unsafe(addr(style.DisabledAlpha)),
                                (id = "STYLE_DISABLED_ALPHA",
                                 text = "Disabled Alpha",
                                 speed = 0.005f, v_min = 0.0f, v_max = 1.0f,
                                 format = "%.2f"))
            }
        }
    }
}
