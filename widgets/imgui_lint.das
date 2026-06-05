options gen2
options indenting = 4
options strict_smart_pointers = true

module imgui_lint shared private

//! dasImgui lint pass — default-on rule catalog.
//!
//! Bundled into ``imgui/imgui_boost_v2`` (and therefore everything that
//! transitively requires it). Runs on every consumer compile by default;
//! opt out per-file via ``options _allow_imgui_legacy = true``.
//!
//! Codes (all macro_error severity, error code 50503; all gated by the
//! single ``_allow_imgui_legacy`` opt-out):
//!   IMGUI001 — call into the dead v1 ``imgui_boost`` module (visitor, this file)
//!   IMGUI002 — raw ``imgui::*`` call not on the allow-list (visitor, this file)
//!   STYLE001 — verbose named-tuple call shape ``widget((field=x))`` where the
//!              single-arg positional form ``widget(x)`` works (implemented in
//!              ``WidgetCallMacro.visit()`` inside imgui_boost.das)
//!
//! The allow-list (``ALLOWED_IMGUI`` below) is the curated set of raw
//! bindings that v2 deliberately doesn't wrap (frame lifecycle, IO/state
//! queries, demo windows, pre-window state). Everything else must go
//! through a [widget] / [container] / with_* wrapper in widgets/.
//!
//! Scoping: walks ``prog.getThisModule`` only, so the lint runs on the
//! consumer file and skips the transitively-required boost modules
//! (which legitimately call raw ``imgui::*`` because that's the whole
//! point of being the wrapper). Wrapper modules under widgets/ also carry
//! ``options _allow_imgui_legacy = true`` defensively so they compile
//! cleanly when targeted directly (MCP compile_check, lint, format_file).

require daslib/ast_boost

let private ALLOWED_IMGUI : table<string> <- {
    // Context / frame lifecycle
    "CreateContext", "DestroyContext", "GetCurrentContext", "SetCurrentContext",
    "NewFrame", "EndFrame", "Render", "GetDrawData",
    // Settings persistence — nulls IniFilename to disable imgui.ini load/save.
    // Host-agnostic config call; tutorials opt in (NOT live_imgui_init), calling
    // it in init() after CreateContext and before the first NewFrame, so the
    // documented FirstUseEver layout / recording is deterministic every run.
    "DisableIniPersistence",
    // IO / per-item state queries (post-widget probes — no v2 host needed)
    "GetIO", "GetStyle", "GetVersion",
    "IsItemHovered", "IsItemActive", "IsItemClicked", "IsItemFocused",
    "IsItemActivated", "IsItemDeactivated", "IsItemDeactivatedAfterEdit",
    "IsItemToggledOpen", "IsItemVisible", "IsItemEdited",
    "IsAnyItemHovered", "IsAnyItemActive", "IsAnyItemFocused",
    "IsWindowFocused", "IsWindowHovered",
    // Mouse / keyboard state queries — pure reads, no widget host.
    "GetMousePos", "GetMousePosOnOpeningCurrentPopup", "IsMousePosValid",
    "IsMouseDown", "IsMouseClicked", "IsMouseReleased", "IsMouseDoubleClicked",
    "IsMouseHoveringRect", "IsAnyMouseDown",
    "GetMouseDragDelta", "ResetMouseDragDelta", "IsMouseDragging",
    "GetMouseCursor", "SetMouseCursor",
    "SetNextFrameWantCaptureMouse", "SetNextFrameWantCaptureKeyboard",
    "IsKeyDown", "IsKeyPressed", "IsKeyReleased",
    "GetKeyName", "GetTime", "GetFrameCount",
    // Drawlist internal query — host-agnostic, used by the style editor's
    // Circle Tessellation preview tooltip to label each sample with its
    // auto-segment count.
    "_CalcCircleAutoSegmentCount",
    // ImVector size accessor (read-only) — e.g. length(dl.VtxBuffer) gives the
    // vertex-index range that the ShadeVerts* family (family 2) operates over.
    "length",
    // Cursor / layout queries (read-only)
    "GetCursorPos", "GetCursorPosX", "GetCursorPosY",
    "GetCursorScreenPos", "GetCursorStartPos",
    "GetContentRegionAvail",
    "GetWindowSize", "GetWindowPos", "GetWindowWidth", "GetWindowHeight",
    "GetItemRectMin", "GetItemRectMax", "GetItemRectSize",
    "CalcTextSize", "CalcItemWidth", "GetTreeNodeToLabelSpacing",
    // Column position queries (read-only) — paired with the columns_open /
    // next_col / columns_close primitives in imgui_layout_builtin.
    "GetColumnIndex", "GetColumnWidth", "GetColumnOffset", "GetColumnsCount",
    // Font / color helpers (read-only)
    "GetFont", "GetFontSize",
    "GetTextLineHeight", "GetTextLineHeightWithSpacing",
    "GetFrameHeight", "GetFrameHeightWithSpacing",
    "GetStyleColorVec4", "GetColorU32", "GetStyleColorName",
    // Demo / debug entry points (built-in windows we deliberately surface as-is)
    "ShowDemoWindow", "ShowMetricsWindow", "ShowDebugLogWindow",
    "ShowIDStackToolWindow", "ShowAboutWindow",
    "ShowStyleEditor", "ShowFontSelector", "ShowStyleSelector",
    "ShowUserGuide",
    // Pre-window state — kept allowed; candidates for future v2-arg absorption.
    "SetNextWindowPos", "SetNextWindowSize", "SetNextWindowSizeConstraints",
    "SetNextWindowContentSize", "SetNextWindowCollapsed", "SetNextWindowFocus",
    "SetNextWindowBgAlpha", "SetNextWindowViewport",
    "SetNextItemWidth", "SetNextItemOpen", "SetNextItemAllowOverlap",
    "SetNextWindowContentWidth",
    "SetColorEditOptions",
    "SetWindowFontScale",
    "SetKeyboardFocusHere", "SetItemDefaultFocus", "SetScrollHereX", "SetScrollHereY",
    "SetScrollX", "SetScrollY", "SetScrollFromPosX", "SetScrollFromPosY",
    "GetScrollX", "GetScrollY",
    "GetScrollMaxX", "GetScrollMaxY",
    // Cursor write-state — paired with the read-side Get* above.
    "SetCursorPos", "SetCursorPosX", "SetCursorPosY", "SetCursorScreenPos",
    "GetWindowContentRegionMax",
    // Drag-drop payload primitives — caller owns memory, payload typing is
    // user-controlled. v2 drag_drop_source/_target containers gate the body;
    // these calls are the payload exchange inside.
    "SetDragDropPayload", "AcceptDragDropPayload", "GetDragDropPayload",
    // Input-text callback primitives — only callable inside an
    // ImGuiInputTextCallbackData callback (which fires synchronously from
    // ImGui::InputText). No widget host needed; caller owns the data pointer.
    "DeleteChars", "InsertChars",
    // Viewport queries.
    "GetMainViewport",
    // Docking internals — DockBuilder* is cherry-picked from imgui_internal.h
    // and used by tests/demos to seed initial layouts. The dockspace/
    // dock_window containers wrap the routine surface; these are the
    // imperative one-shot setup calls.
    "DockBuilderRemoveNode", "DockBuilderAddDockSpaceNode",
    "DockBuilderSetNodeSize", "DockBuilderSetNodePos",
    "DockBuilderSplitNode", "DockBuilderDockWindow", "DockBuilderFinish",
    "DockBuilderGetNode", "DockBuilderCopyNode",
    "DockSpace", "DockSpaceOverViewport", "GetID",
    // Low-level draw primitives cherry-picked from imgui_internal.h (family 1).
    // Host-agnostic: they render directly into an ImDrawList / the current
    // window with no v2 host state. Bound via bind_imgui.das internal_allow_func.
    "RenderFrame", "RenderFrameBorder", "RenderText", "RenderTextWrapped",
    "RenderColorRectWithAlphaCheckerboard", "RenderMouseCursor",
    "RenderArrow", "RenderBullet", "RenderCheckMark",
    "RenderArrowPointingAt", "RenderArrowDockMenu",
    // Render*Clipped / Ellipsis text helpers — bound via manual C++ wrappers
    // (dasIMGUI.main.cpp) that pin text_end/text_size_if_known to nullptr, since a
    // daslang string can't pass the NULL these need (a non-null "" over-reads → crash).
    "RenderTextClipped", "RenderTextClippedEx", "RenderTextEllipsis",
    // Vertex-shading draw helpers cherry-picked from imgui_internal.h (family 2).
    // Write over already-created ImDrawList vertices — host-agnostic, no v2 state.
    // Bound via bind_imgui.das internal_allow_func.
    "ShadeVertsLinearColorGradientKeepAlpha", "ShadeVertsLinearUV",
    "ShadeVertsTransformPos",
    // Item / layout helpers cherry-picked from imgui_internal.h (family 4).
    // Geometry math (CalcItemSize/CalcWrapWidthForPos/GetContentRegionMaxAbs) plus
    // ItemSize (reserve layout space for a custom-drawn item) — host-agnostic, no v2
    // state. Bound via bind_imgui.das internal_allow_func; ImRect arg of ItemSize's
    // rect overload is aliased to float4 (cb_dasIMGUI.h).
    "CalcItemSize", "CalcWrapWidthForPos", "GetContentRegionMaxAbs", "ItemSize",
    // Family 1-complete — Render* helpers that take an ImRect, dropped from family 1
    // until ImRect was aliased to float4 (#166). RenderDragDropTargetRect/RenderNavHighlight
    // draw into the current window; RenderRectFilledRangeH/WithHole take an ImDrawList.
    // Host-agnostic, no v2 state. Bound via bind_imgui.das internal_allow_func.
    "RenderDragDropTargetRect", "RenderNavHighlight",
    "RenderRectFilledRangeH", "RenderRectFilledWithHole",
    // ID-stack seed / override helpers cherry-picked from imgui_internal.h.
    // Host-agnostic: hash/seed an ImGuiID, query the active/hovered/focus ID, or
    // push a raw override onto the ID stack. Bound via bind_imgui.das
    // internal_allow_func. GetActiveID is bound separately (das::GetActiveID wrapper).
    "GetFocusID", "GetHoveredID", "KeepAliveID", "MarkItemEdited",
    "PushOverrideID", "GetIDWithSeed", "TreePushOverrideID",
    // Focus-scope + activation stack cherry-picked from imgui_internal.h.
    // Host-agnostic: push/query a focus scope (nav + multi-select grouping),
    // focus/activate an item by ID, or set the next item's selection user-data.
    // Bound via bind_imgui.das internal_allow_func; v2 guard with_focus_scope.
    "PushFocusScope", "PopFocusScope", "GetCurrentFocusScope",
    "FocusItem", "ActivateItemByID", "SetNextItemSelectionUserData"
}

class ImguiLintVisitor : AstVisitor {
    @do_not_delete current_function : Function?

    def override preVisitFunction(var fn : FunctionPtr) : void {
        current_function = fn
    }

    def override visitFunction(var fn : FunctionPtr) : FunctionPtr {
        current_function = null
        return <- fn
    }

    def override preVisitExprCall(var expr : ExprCall?) : void {
        // Combined skip: null guards, macro-generated function bodies, AND
        // macro-synthesized call sites (qmacro emits ExprCalls whose `at`
        // points at the macro template's source file, not the user's file —
        // skip when fileInfo differs from the containing function's).
        if (expr.func == null || expr.func._module == null
                || (current_function != null
                    && (current_function.flags.generated
                        || (current_function.at.fileInfo != null
                            && expr.at.fileInfo != current_function.at.fileInfo)))) return
        let mname = string(expr.func._module.name)
        if (mname == "imgui_boost") {
            let fname = string(expr.func.name)
            compiling_program() |> macro_error(expr.at,
                "IMGUI001: legacy imgui_boost::{fname} is dead — use the v2 wrapper in modules/dasImgui/widgets/. See modules/dasImgui/skills/migration.md for the v1->v2 mapping table.")
        } elif (mname == "imgui") {
            let fname = string(expr.func.name)
            if (!key_exists(ALLOWED_IMGUI, fname)) {
                compiling_program() |> macro_error(expr.at,
                    "IMGUI002: raw imgui::{fname} is forbidden — add a [widget]/[container]/with_* wrapper in modules/dasImgui/widgets/, or extend ALLOWED_IMGUI in imgui_lint.das if {fname} is genuinely host-agnostic. Per-file escape: `options _allow_imgui_legacy = true`. See modules/dasImgui/skills/migration.md for the v1->v2 mapping table.")
            }
        }
    }
}

[lint_macro]
class ImguiLintMacro : AstPassMacro {
    def override apply(prog : ProgramPtr; mod : Module?) : bool {
        let opted_out = prog._options |> find_arg("_allow_imgui_legacy") ?as tBool ?? false
        if (opted_out) return true
        var v = new ImguiLintVisitor()
        make_visitor(*v) $(adapter) {
            visit_module(prog, adapter, prog.getThisModule)
        }
        unsafe { delete v; }
        return true
    }
}
