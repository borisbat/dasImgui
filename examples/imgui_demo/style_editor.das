options gen2
options indenting = 4

module style_editor

require imgui
require imgui/imgui_widgets_builtin
require imgui/imgui_containers_builtin
require daslib/enum_trait

// Mirrors imgui_demo.cpp:6680-6962 — void ImGui::ShowStyleEditor(ImGuiStyle* ref).
//
// Scope notes for the daslang port:
//   - This function does NOT open its own window; the caller is expected to
//     wrap it in a Begin/End (or boost `window(...)`). Same shape as C++.
//   - ALL the sliders here edit fields of ImGui's live style struct via raw
//     `SliderFloat(label, unsafe(addr(style.X)), ...)`. The boost-layer
//     `slider_float` is designed for "we own the value" semantics and doesn't
//     fit this "we edit external state" case. Phase 3 of the masterplan
//     (see ~/.claude/plans/declarative-splashing-pelican.md) adds boost
//     external-pointer variants; once landed, this file can opportunistically
//     modernize the slider/checkbox/drag/color-edit calls. Until then we use
//     `unsafe(addr(...))` directly because `safe_addr` is local-var-only and
//     doesn't accept struct-field lvalues reached through a reference.
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

    PushItemWidth(GetWindowWidth() * 0.50f)

    // Built-in style/font pickers.
    if (ShowStyleSelector("Colors##Selector")) {}
    ShowFontSelector("Fonts##Selector")

    // "Simplified Settings": one float slider editing style.FrameRounding.
    unsafe {
        if (SliderFloat("FrameRounding", addr(style.FrameRounding),
                        0.0f, 12.0f, "%.0f", ImGuiSliderFlags.None)) {
            // C++ keeps GrabRounding == FrameRounding for visual consistency.
            style.GrabRounding = style.FrameRounding
        }
    }

    Separator()

    tab_bar(STYLE_TABS, (text = "##tabs", flags = ImGuiTabBarFlags.None)) {
        tab_item(STYLE_TAB_SIZES, (text = "Sizes", closable = false,
                                   flags = ImGuiTabItemFlags.None)) {
            SeparatorText("Main")
            // SliderFloat2 calls on WindowPadding/FramePadding/ItemSpacing/
            // ItemInnerSpacing/TouchExtraPadding skipped pending Phase 3.
            // See imgui_demo.cpp:6729-6733.
            unsafe {
                SliderFloat("IndentSpacing", addr(style.IndentSpacing),
                            0.0f, 30.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("ScrollbarSize", addr(style.ScrollbarSize),
                            1.0f, 20.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("GrabMinSize", addr(style.GrabMinSize),
                            1.0f, 20.0f, "%.0f", ImGuiSliderFlags.None)
            }

            SeparatorText("Borders")
            unsafe {
                SliderFloat("WindowBorderSize", addr(style.WindowBorderSize),
                            0.0f, 1.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("ChildBorderSize", addr(style.ChildBorderSize),
                            0.0f, 1.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("PopupBorderSize", addr(style.PopupBorderSize),
                            0.0f, 1.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("FrameBorderSize", addr(style.FrameBorderSize),
                            0.0f, 1.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("TabBorderSize", addr(style.TabBorderSize),
                            0.0f, 1.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("TabBarBorderSize", addr(style.TabBarBorderSize),
                            0.0f, 2.0f, "%.0f", ImGuiSliderFlags.None)
            }

            SeparatorText("Rounding")
            unsafe {
                SliderFloat("WindowRounding", addr(style.WindowRounding),
                            0.0f, 12.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("ChildRounding", addr(style.ChildRounding),
                            0.0f, 12.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("PopupRounding", addr(style.PopupRounding),
                            0.0f, 12.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("ScrollbarRounding", addr(style.ScrollbarRounding),
                            0.0f, 12.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("GrabRounding", addr(style.GrabRounding),
                            0.0f, 12.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("TabRounding", addr(style.TabRounding),
                            0.0f, 12.0f, "%.0f", ImGuiSliderFlags.None)
            }

            SeparatorText("Misc")
            unsafe {
                SliderFloat("SeparatorTextBorderSize",
                            addr(style.SeparatorTextBorderSize),
                            0.0f, 10.0f, "%.0f", ImGuiSliderFlags.None)
                SliderFloat("LogSliderDeadzone", addr(style.LogSliderDeadzone),
                            0.0f, 12.0f, "%.0f", ImGuiSliderFlags.None)
            }

            SeparatorText("Docking")
            unsafe {
                SliderFloat("DockingSplitterSize",
                            addr(style.DockingSeparatorSize),
                            0.0f, 12.0f, "%.0f", ImGuiSliderFlags.None)
            }
        }

        tab_item(STYLE_TAB_COLORS, (text = "Colors", closable = false,
                                    flags = ImGuiTabItemFlags.None)) {
            // Stripped-down color editor: one ColorEdit4 per ImGuiCol entry.
            // Skipped vs C++: filter widget, export-to-clipboard, alpha-mode
            // radio group, and per-color Save/Revert buttons (see file-level
            // doc comment).
            BeginChild("##colors", float2(0.0f, 0.0f),
                       ImGuiChildFlags.Border,
                       ImGuiWindowFlags.AlwaysVerticalScrollbar)
            PushItemWidth(GetFontSize() * -12.0f)
            for (col in type<ImGuiCol>) {
                if (col == ImGuiCol.COUNT) continue
                let name = GetStyleColorName(col)
                PushID(int(col))
                unsafe {
                    ColorEdit4("##color",
                               reinterpret<float?>(addr(style.Colors[int(col)])),
                               ImGuiColorEditFlags.AlphaBar)
                }
                SameLine(0.0f, style.ItemInnerSpacing.x)
                TextUnformatted(name)
                PopID()
            }
            PopItemWidth()
            EndChild()
        }

        tab_item(STYLE_TAB_FONTS, (text = "Fonts", closable = false,
                                   flags = ImGuiTabItemFlags.None)) {
            // ShowFontAtlas (cpp:6872) skipped — debug helper.
            // Window-scoped font scale (cpp:6885) skipped — needs window state.
            var io & = unsafe(GetIO())
            unsafe {
                DragFloat("global scale", addr(io.FontGlobalScale),
                          0.005f, 0.3f, 2.0f, "%.2f",
                          ImGuiSliderFlags.AlwaysClamp)
            }
        }

        tab_item(STYLE_TAB_RENDERING, (text = "Rendering", closable = false,
                                       flags = ImGuiTabItemFlags.None)) {
            unsafe {
                Checkbox("Anti-aliased lines", addr(style.AntiAliasedLines))
                Checkbox("Anti-aliased lines use texture",
                         addr(style.AntiAliasedLinesUseTex))
                Checkbox("Anti-aliased fill", addr(style.AntiAliasedFill))
                DragFloat("Curve Tessellation Tolerance",
                          addr(style.CurveTessellationTol),
                          0.02f, 0.10f, 10.0f, "%.2f", ImGuiSliderFlags.None)
                if (style.CurveTessellationTol < 0.10f) {
                    style.CurveTessellationTol = 0.10f
                }
                // Circle Tessellation preview tooltip (cpp:6909-6947) skipped.
                DragFloat("Circle Tessellation Max Error",
                          addr(style.CircleTessellationMaxError),
                          0.005f, 0.10f, 5.0f, "%.2f",
                          ImGuiSliderFlags.AlwaysClamp)
                DragFloat("Global Alpha", addr(style.Alpha),
                          0.005f, 0.20f, 1.0f, "%.2f", ImGuiSliderFlags.None)
                DragFloat("Disabled Alpha", addr(style.DisabledAlpha),
                          0.005f, 0.0f, 1.0f, "%.2f", ImGuiSliderFlags.None)
            }
        }
    }

    PopItemWidth()
}
